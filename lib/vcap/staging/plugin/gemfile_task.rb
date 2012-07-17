require "logger"
require "fileutils"
require "bundler"

class GemfileTask

  def initialize(app_dir, library_version, ruby_cmd, base_dir, uid=nil, gid=nil)
    @app_dir          = File.expand_path(app_dir)
    @library_version  = library_version
    @cache_base_dir   = File.join(base_dir, @library_version)
    @blessed_gems_dir = File.join(@cache_base_dir, "blessed_gems")
    FileUtils.mkdir_p(@blessed_gems_dir)

    @ruby_cmd = ruby_cmd
    @uid = uid
    @gid = gid

    log_file = File.expand_path(File.join(@app_dir, "..", "logs", "staging.log"))
    FileUtils.mkdir_p(File.dirname(log_file))

    @logger = Logger.new(log_file)
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    @logger.formatter = lambda { |sev, time, pname, msg| "#{msg}\n" }

    @cache = GemCache.new(File.join(@cache_base_dir, "gem_cache"))
  end

  def lockfile_path
    File.join(@app_dir, "Gemfile.lock")
  end

  def locked_dependencies
    return @locked unless @locked.nil?
    lockfile = File.read(lockfile_path)
    @locked = Bundler::LockfileParser.new(lockfile)
  end

  # TODO - Inject EM.system-compatible control here.
  def install
    install_specs(locked_dependencies.specs)
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

  # Each dependency is a Bundler::Spec object
  def install_specs(specs)
    specs.each do |spec|
      install_gem(spec.name, spec.version.version, spec.source)
    end
  end

  def install_bundler
    install_gem("bundler", "1.0.10")
  end

  def install_local_gem(gem_dir, gem_filename, gem_name, gem_version)
    blessed_gem_path = File.join(@blessed_gems_dir, gem_filename)
    if File.exists?(blessed_gem_path)
       install_gem_from_path(gem_filename, blessed_gem_path, "blessed")
    else
       local_path = File.join(gem_dir, gem_filename)
       install_gem_from_path(gem_filename, local_path, "local")
       save_blessed_gem(local_path)
    end
  end

  # The application includes some version of the specified gem in its bundle
  def bundles_gem?(gem_name)
    locked_dependencies.specs.any? { |spec| spec.name == gem_name }
  end

  # source is Bundler::Source object, defaults to rubygems
  def install_gem(name, version, source=nil)
    gem_filename = gem_filename(name, version)

    user_gem_path = File.join(@app_dir, "vendor", "cache", gem_filename)

    if File.exists?(user_gem_path)
      install_gem_from_path(gem_filename, user_gem_path, "user")
    else
      if source.kind_of?(Bundler::Source::Git)
        # Do git stuff
        raise "Failed installing gem #{gem_filename}: git URLs are not supported"
      else
        # assuming Rubygems
        blessed_gem_path = File.join(@blessed_gems_dir, gem_filename)
        if File.exists?(blessed_gem_path)
          install_gem_from_path(gem_filename, blessed_gem_path, "blessed")
        else
          @logger.info("Need to fetch #{gem_filename} from RubyGems")
          Dir.mktmpdir do |tmp_dir|
            fetched_path = fetch_gem_from_rubygems(name, version, tmp_dir)
            install_gem_from_path(gem_filename, fetched_path, "fetched")
            save_blessed_gem(fetched_path)
          end
        end
      end
    end
  end

  private

  def save_blessed_gem(gem_path)
    return unless File.exists?(gem_path)
    output = `cp -n #{gem_path} #{@blessed_gems_dir} 2>&1`
    if $?.exitstatus != 0
      @logger.debug "Failed adding #{gem_path} to #{@blessed_gems_dir}: #{output}"
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
    @logger.info "Adding #{gem_filename} to app..."
    copy_gem_to_app(installed_gem_path)
  end

  def copy_gem_to_app(src)
    return unless src && File.exists?(src)
    FileUtils.mkdir_p(installation_directory)
    `cp -a #{src}/* #{installation_directory}`
  end

  def installation_directory
    File.join(@app_dir, 'rubygems', 'ruby', @library_version)
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
      @logger.debug "Failed copying #{src} to #{tmp_dir}: #{output}"
      return nil
    end

    staged_gemfile = File.join(tmp_dir, File.basename(src))

    output = `chmod -R 0744 #{staged_gemfile} 2>&1`
    if $?.exitstatus != 0
      @logger.debug "Failed chmodding #{tmp_dir}: #{output}"
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
      user = `whoami`.chomp
      `sudo /bin/chown -R #{user} #{tmp_dir}` if @uid
      FileUtils.rm_rf(tmp_dir)
    end

    # Copy gemfile into tempdir, make sure secure user can read it
    staged_gemfile = stage_gemfile_for_install(gemfile_path, tmp_dir)
    unless staged_gemfile
      @logger.debug "Failed copying gemfile to staging dir for install"
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

    if @uid
      chmod_output = `/bin/chmod 0755 #{gem_install_dir} 2>&1`
      if $?.exitstatus != 0
        @logger.error "Failed chmodding install dir: #{chmod_output}"
        return nil
      end

      chown_output = `sudo /bin/chown -R #{@uid} #{tmp_dir} 2>&1`
      if $?.exitstatus != 0
        @logger.debug "Failed chowning install dir: #{chown_output}"
        return nil
      end
    end

    @logger.debug("Doing a gem install from #{staged_gemfile} into #{gem_install_dir} as user #{@uid || 'cc'}")
    staging_cmd = "#{@ruby_cmd} -S gem install #{staged_gemfile} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{gem_install_dir}"
    staging_cmd = "cd / && sudo -u '##{@uid}' #{staging_cmd}" if @uid

    # Finally, do the install
    pid = fork
    if pid
      # Parent, wait for staging to complete
      Process.waitpid(pid)
      child_status = $?

      # Kill any stray processes that the gem compilation may have created
      if @uid
        `sudo -u '##{@uid}' pkill -9 -U #{@uid} 2>&1`
        me = `whoami`.chomp
        `sudo chown -R #{me} #{tmp_dir}`
        @logger.debug "Failed chowning #{tmp_dir} to #{me}" if $?.exitstatus != 0
      end

      if child_status.exitstatus != 0
        @logger.debug("Failed executing #{staging_cmd}")
        nil
      else
        @logger.debug("Success!")
        gem_install_dir
      end
    else
      close_fds
      exec(staging_cmd)
    end
  end

  def close_fds
    3.upto(get_max_open_fd) do |fd|
      begin
        IO.for_fd(fd, "r").close
      rescue
      end
    end
  end

  def get_max_open_fd
    max = 0

    dir = nil
    if File.directory?("/proc/self/fd/") # Linux
      dir = "/proc/self/fd/"
    elsif File.directory?("/dev/fd/") # Mac
      dir = "/dev/fd/"
    end

    if dir
      Dir.foreach(dir) do |entry|
        begin
          pid = Integer(entry)
          max = pid if pid > max
        rescue
        end
      end
    else
      max = 65535
    end

    max
  end

end
