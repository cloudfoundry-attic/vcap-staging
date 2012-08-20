require "logger"
require "fileutils"
require File.expand_path('../gem_cache', __FILE__)
require File.expand_path('../git_cache', __FILE__)
require File.expand_path('../secure_operations', __FILE__)
require File.expand_path('../gemspec_builder', __FILE__)

class GemfileTask
  include SecureOperations

  def initialize(app_dir, library_version, ruby_cmd, base_dir, options={}, uid=nil, gid=nil)
    @app_dir          = File.expand_path(app_dir)
    @library_version  = library_version
    @cache_base_dir   = File.join(base_dir, @library_version)
    @blessed_gems_dir = File.join(@cache_base_dir, "blessed_gems")
    FileUtils.mkdir_p(@blessed_gems_dir)

    @ruby_cmd = ruby_cmd
    @uid = uid
    @gid = gid
    @options = options

    log_file = File.expand_path(File.join(@app_dir, "..", "logs", "staging.log"))
    FileUtils.mkdir_p(File.dirname(log_file))

    @logger = Logger.new(log_file)
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    @logger.formatter = lambda { |sev, time, pname, msg| "#{msg}\n" }

    @cache = GemCache.new(File.join(@cache_base_dir, "gem_cache"))
    git_repo_dir = File.join(base_dir, "git_cache")
    git_compiled_gems_dir = File.join(@cache_base_dir, "git_gems")
    @git_cache = GitCache.new(git_repo_dir, git_compiled_gems_dir, @logger)
  end

  def specs
    @specs ||= \
    begin
      tmp_dir = Dir.mktmpdir
      at_exit do
        secure_delete(tmp_dir)
      end
      # Copy the app to a directory visible by secure user
      system "cp -a #{File.join(@app_dir, "*")} #{tmp_dir}"
      spec_file = File.join(tmp_dir,"specs")
      spec_cmd = "#{@ruby_cmd} #{File.expand_path('../gemfile_parser.rb', __FILE__)} #{spec_file}"
      spec_cmd = "#{spec_cmd} \"#{@options[:bundle_without]}\"" if @options[:bundle_without]
      exitstatus, _ = run_secure(spec_cmd, tmp_dir)
      if exitstatus != 0
        raise "Error resolving Gemfile"
      end
      YAML.load_file(spec_file)
    end
  end

  def install
   install_specs(specs)
  end

  def remove_gems_cached_in_app
    FileUtils.rm_rf(File.join(installation_directory, "cache"))
  end

  # Each dependency is a gem [name, version] pair;
  # e.g. ['thin', '1.2.10']
  def install_gems(gems)
    gems.each do |(name, version)|
      install_gem(name, version)
    end
  end

  def install_specs(specs)
    specs.each do |spec|
      if spec[:source][:type] == "Bundler::Source::Git"
        install_git_gem(spec)
      else
        install_gem(spec[:name], spec[:version])
      end
    end
  end

  def install_bundler
    install_gem("bundler", "1.1.3")
  end

  def install_local_gem(gem_dir, gem_filename)
    blessed_gem_path = File.join(@blessed_gems_dir, gem_filename)
    if File.exists?(blessed_gem_path)
      installed_path = install_gem_from_path(gem_filename, blessed_gem_path, "blessed")
    else
      local_path = File.join(gem_dir, gem_filename)
      installed_path = install_gem_from_path(gem_filename, local_path, "local")
      save_blessed_gem(local_path)
    end
    copy_gem_to_app(gem_filename, installed_path, installation_directory)
  end

  def bundles_gem?(gem_name)
    specs.any? { |spec| spec[:name] == gem_name }
  end

  def install_gem(name, version)
    gem_filename = gem_filename(name, version)
    user_gem_path = File.join(@app_dir, "vendor", "cache", gem_filename)
    installed_path = nil

    if File.exists?(user_gem_path)
      installed_path = install_gem_from_path(gem_filename, user_gem_path, "user")
    else
      blessed_gem_path = File.join(@blessed_gems_dir, gem_filename)
      if File.exists?(blessed_gem_path)
       installed_path = install_gem_from_path(gem_filename, blessed_gem_path, "blessed")
      else
        @logger.info("Need to fetch #{gem_filename} from RubyGems")
        Dir.mktmpdir do |tmp_dir|
          fetched_path = fetch_gem_from_rubygems(name, version, tmp_dir)
          installed_path = install_gem_from_path(gem_filename, fetched_path, "fetched")
          save_blessed_gem(fetched_path)
        end
      end
    end
    copy_gem_to_app(gem_filename, installed_path, installation_directory)
  end

  def install_git_gem(spec)
    gem_filename = gem_filename(spec[:name], spec[:version])
    unless spec[:source][:revision]
      # Revision should be always provided in lock file
      raise "Failed installing git gem #{gem_filename}: revision is required"
    end
    dest = File.join(installation_directory, "bundler", "gems", spec[:source][:git_scope])
    # Skip in case we already processed request for gem in the same git scope
    return nil if File.exists?(dest)

    # Check compiled gems cache
    cached_gem_path = @git_cache.get_compiled_gem(spec[:source][:revision])
    if cached_gem_path
      copy_gem_to_app(gem_filename, cached_gem_path, dest)
    else
      begin
        # Get the source of the given revision
        @logger.info("Need to fetch #{gem_filename} from Git source")

        tmp_dir = Dir.mktmpdir
        tmp_source_path = @git_cache.get_source(spec[:source], tmp_dir)
        gem_logname = "#{spec[:name]}-#{spec[:source][:revision]}"
        raise "Failed fetching gem #{gem_logname} from source" unless tmp_source_path

        # Build all gemspecs with extensions in source
        gemspecs = Dir.glob(File.join(tmp_source_path, "{,*,*/*}.gemspec"))
        # Add access to whole source to compilation user
        secure_file(tmp_source_path)
        required_build = false

        gemspecs.each do |gemspec_path|
          gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
          unsecure_file(gemspec.base_dir)

          # Only build gem if it has extensions
          if gemspec.requires_build?
            required_build = true

            # Build gemspec
            gem_path = gemspec.build
            raise "Failed building #{gemspec.filename}" unless gem_path

            # Install gem
            gem_full_name = File.basename(gem_path, ".gem")
            installed_path = compile_gem(gem_path)
            raise "Failed installing git gem #{gem_full_name}" unless installed_path
            FileUtils.rm_f(gem_path)

            # Copy installed contents back to source
            installed_gem_dir = File.join(installed_path, "gems", gem_full_name)
            copy_dir_contents(installed_gem_dir, gemspec.base_dir)
            spec_file = File.join(installed_path, "specifications", "#{gem_full_name}.gemspec")
            gemspec.update_from_path(spec_file)
          else
            # Evaluate gemspec
            gemspec.update
          end
        end
        # Put the source in app where bundler expects to see it
        FileUtils.rm_rf(File.join(tmp_source_path, ".git"))
        copy_gem_to_app(gem_filename, tmp_source_path, dest)

        # Put in compiled cache if we needed to build it
        @git_cache.put_compiled_gem(tmp_source_path, spec[:source][:revision]) if required_build
      ensure
        secure_delete(tmp_dir)
      end
    end
  end

  private

  def save_blessed_gem(gem_path)
    return unless File.exists?(gem_path)
    output = `cp -n #{gem_path} #{@blessed_gems_dir} 2>&1`
    if $?.exitstatus != 0
      @logger.debug "Failed adding #{gem_path} to blessed gems dir: #{output}"
    end
  end

  def install_gem_from_path(gem_filename, gem_path, type)
    return unless File.exists?(gem_path)
    installed_gem_path = @cache.get(gem_path)
    unless installed_gem_path
      @logger.debug "Installing #{type} gem: #{gem_path}"

      tmp_gem_dir = compile_gem(gem_path)
      raise "Failed installing #{gem_filename}" unless tmp_gem_dir

      installed_gem_path = @cache.put(gem_path, tmp_gem_dir)
    end
    installed_gem_path
  end

  def copy_gem_to_app(gem_filename, src, dest)
    @logger.info("Adding #{gem_filename} to app...")
    copy_dir_contents(src, dest)
  end

  def copy_dir_contents(src, dest)
    unsecure_file(src)
    return unless src && File.exists?(src)
    FileUtils.mkdir_p(dest)
    begin
      FileUtils.copy_entry(src, dest)
    rescue
      @logger.error "Failed copying gem to #{dest}"
    end
  end

  def installation_directory
    File.join(@app_dir, "rubygems", "ruby", @library_version)
  end

  def fetch_gem_from_rubygems(name, version, directory)
    url = rubygems_url_for(name, version)
    gem_filename = gem_filename(name, version)
    cmd = "wget --quiet --retry-connrefused --connect-timeout=5 --no-check-certificate #{url}"

    Dir.chdir(directory) do
      raise "Failed fetching missing gem #{gem_filename} from Rubygems" unless system(cmd)
    end

    File.join(directory, gem_filename)
  end

  def gem_filename(name, version)
    "%s-%s.gem" % [ name, version ]
  end

  def rubygems_url_for(name, version)
    "http://production.s3.rubygems.org/gems/#{name}-#{version}.gem"
  end

  # Stage the gemfile in a temporary directory that is readable by a secure user
  # We may be able to get away with mv here instead of a cp
  def stage_gemfile_for_install(src, tmp_dir)
    output = `cp #{src} #{tmp_dir} 2>&1`
    if $?.exitstatus != 0
      @logger.error "Failed copying #{src} to #{tmp_dir}: #{output}"
      return nil
    end

    staged_gemfile = File.join(tmp_dir, File.basename(src))

    output = `chmod -R 0744 #{staged_gemfile} 2>&1`
    if $?.exitstatus != 0
      @logger.error "Failed chmodding #{tmp_dir}: #{output}"
      nil
    else
      staged_gemfile
    end
  end

  # Perform a gem install from src_dir into a temporary directory
  def compile_gem(gemfile_path)
    # Create tempdir that will house everything
    tmp_dir = Dir.mktmpdir
    at_exit do
      secure_delete(tmp_dir)
    end

    # Copy gemfile into tempdir, make sure secure user can read it
    staged_gemfile = stage_gemfile_for_install(gemfile_path, tmp_dir)
    unless staged_gemfile
      @logger.error "Failed copying gemfile to staging dir for install"
      return nil
    end

    # Create a temp dir that the user can write into (gem install into)
    gem_install_dir = File.join(tmp_dir, 'gem_install_dir')
    begin
      Dir.mkdir(gem_install_dir)
    rescue => e
      @logger.error "Failed creating gem install dir: #{e}"
      return nil
    end

    @logger.debug("Doing a gem install from #{staged_gemfile} into #{gem_install_dir} as user #{@uid || 'cc'}")
    staging_cmd = "#{@ruby_cmd} -S gem install #{staged_gemfile} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{gem_install_dir}"
    exitstatus, _ = run_secure(staging_cmd, tmp_dir)
    exitstatus == 0 ? gem_install_dir : nil
  end
end
