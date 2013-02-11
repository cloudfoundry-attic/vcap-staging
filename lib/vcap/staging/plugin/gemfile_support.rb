require File.expand_path('../gemfile_task', __FILE__)

module GemfileSupport

  # OK, so this is our workhorse.
  # 1. If file has no Gemfile.lock we never attempt to outsmart it, just stage it as is.
  # 2. If app has been a subject to 'bundle install --local --deployment' we ignore it as
  #    user seems to be confident it just work in the environment he pushes into.
  # 3. If app has been 'bundle package'd we attempt to compile and cache its gems so we can
  #    bypass compilation on the next staging (going to step 4 for missing gems).
  # 4. If app just has Gemfile.lock, we fetch gems from Rubygems and cache them locally, then
  #    compile them and cache compilation results (using the same cache as in step 3).
  # 5. Finally we just copy all these files back to a well-known location the app honoring
  #    Rubygems path structure.
  # NB: ideally this should be refactored into a set of saner helper classes, as it's really
  # hard to follow who calls what and where.
  def compile_gems
    return unless uses_bundler?
    return if packaged_with_bundler_in_deployment_mode?

    gem_task.install_bundler
    gem_task.install
    gem_task.remove_gems_cached_in_app

    write_bundle_config
  end

  def ruby_cmd
    safe_env = [ "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "C_INCLUDE_PATH", "LIBRARY_PATH" ].map { |e| "#{e}='#{ENV[e]}'" }.join(" ")

    path = ENV["PATH"] || "/bin:/usr/bin:/sbin:/usr/sbin"
    path = File.dirname(ruby) + ":" + path if ruby[0] == "/"
    safe_env << " PATH='#{path}'"

    safe_env << " LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"
    safe_env << " GEM_PATH='%GEM_PATH%'"

    "env -i #{safe_env} #{ruby}"
  end

  def gem_task
    return @task if @task
    base_dir = StagingPlugin.platform_config["cache"]
    @task = GemfileTask.new(app_dir, library_version, ruby_cmd, base_dir,
      runtime[:version], logger, {:bundle_without=>bundle_without}, @staging_uid, @staging_gid)
  end

  def library_version
    runtime[:version] =~ /\A1\.9/ ? "1.9.1" : "1.8"
  end

  def bundle_without
    excluded_groups= @bundle_without || "test"
    without = environment[:environment].find {|env| env =~ /\ABUNDLE_WITHOUT=/} if environment[:environment]
    if without
      if without.split('=').last.strip == "BUNDLE_WITHOUT"
        # Support override of default test exclusion with "BUNDLE_WITHOUT="
        excluded_groups = nil
      else
        excluded_groups = without.split('=').last
      end
    end
    excluded_groups
  end

  # Can we expect to run this app on Rack?
  def rack?
    gem_task.bundles_gem?("rack")
  end

  # Can we expect to run this app on Thin?
  def thin?
    gem_task.bundles_gem?("thin")
  end

  def uses_bundler?
    File.exists?(File.join(source_directory, 'Gemfile.lock'))
  end

  # The application includes some version of the specified gem in its bundle
  def bundles_gem?(gem_name)
    gem_task.bundles_gem?(gem_name)
  end

  def gem_info(gem_name)
    gem_task.gem_info(gem_name)
  end

  def packaged_with_bundler_in_deployment_mode?
    File.directory?(File.join(source_directory, 'vendor', 'bundle', library_version))
  end

  def install_local_gem(gem_dir, gem_filename)
    gem_task.install_local_gem(gem_dir, gem_filename)
  end

  def install_gems(gems)
    gem_task.install_gems(gems)
  end

  # This sets a relative path to the bundle directory, so nothing is confused
  # after the app is unpacked on a DEA.
  def write_bundle_config
    config = <<-CONFIG
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
CONFIG
    config << "BUNDLE_WITHOUT: #{bundle_without}" + "\n"  if !bundle_without.nil?
    dot_bundle = File.join(destination_directory, 'app', '.bundle')
    FileUtils.mkdir_p(dot_bundle)
    File.open(File.join(dot_bundle, 'config'), 'wb') do |config_file|
      config_file.print(config)
    end
  end
end

