class RackPlugin < StagingPlugin
  include GemfileSupport

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      compile_gems
      install_autoconfig_gem if autoconfig_enabled?
      create_startup_script
      create_stop_script
    end
  end

  def start_command
    if uses_bundler?
      "#{local_runtime} #{bundler_cmd} exec #{local_runtime} -S ./#{gem_bin_dir}/rackup $@ config.ru -E $RACK_ENV"
    else
      "#{local_runtime} -S rackup $@ config.ru -E $RACK_ENV"
    end
  end

  private
  def startup_script
    vars = ruby_startup_vars
     vars['RACK_ENV'] = '${RACK_ENV:-production}'
    # PWD here is after we change to the 'app' directory.
    generate_startup_script(vars) do
      plugin_specific_startup
    end
  end

  def stop_script
    generate_stop_script
  end

  def plugin_specific_startup
    cmds = []
    cmds << "mkdir ruby"
    cmds << 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb'
    cmds.join("\n")
  end
end
