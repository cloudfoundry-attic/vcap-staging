require File.expand_path("../database_support", __FILE__)
require File.expand_path("../../secure_operations", __FILE__)
require "uuidtools"

class Rails3Plugin < StagingPlugin
  include GemfileSupport
  include RailsDatabaseSupport
  include SecureOperations

  # PWD here is after we change to the 'app' directory.
  def start_command
    if uses_bundler?
      # Specify Thin if the app bundled it; otherwise let Rails figure it out.
      server_script = thin? ? "server thin" : "server"
      "#{local_runtime} #{bundler_cmd} exec #{local_runtime} ./#{gem_bin_dir}/rails #{server_script} $@"
    else
      "#{local_runtime} -S thin -R config.ru $@ start"
    end
  end

  def migration_enabled?
    cf_config_file =  destination_directory + '/app/config/cloudfoundry.yml'
    if File.exists? cf_config_file
      config = YAML.load_file(cf_config_file)
      if config && config['dbmigrate'] == false
        return false
      end
    end
    true
  end

  def migration_command
    if uses_bundler?
      "#{local_runtime} #{bundler_cmd} exec #{local_runtime} ./#{gem_bin_dir}/rake db:migrate --trace"
    else
      "#{local_runtime} -S rake db:migrate --trace"
    end
  end

  def console_command
   if uses_bundler?
      "#{local_runtime} #{bundler_cmd} exec #{local_runtime} cf-rails-console/rails_console.rb"
    else
      "#{local_runtime} cf-rails-console/rails_console.rb"
    end
  end

  def precompile_assets_command(where)
    cmd = ruby_cmd
    gem_path = File.dirname(File.join(where, gem_bin_dir))
    cmd = cmd.gsub("%GEM_PATH%", gem_path)
    # This task loads initializers by default, that may require db connection
    # Right now cfautoconfig can't work on stager, so such applications need to set:
    # config.assets.initialize_on_precompile = false in application.rb
    # TODO: set this options by default or turn on live compilation
    # or make cfautoconfig work on stager
    if uses_bundler?
      "#{cmd} #{bundler_cmd} exec ./#{gem_bin_dir}/rake assets:precompile"
    else
      "#{cmd} -S rake assets:precompile"
    end
  end

  def resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def stage_application
    @bundle_without = excluded_groups
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      stage_console
      compile_gems
      if autoconfig_enabled?
        configure_database # TODO - Fail if we just configured a database that the user did not bundle a driver for.
        install_autoconfig_gem
      end
      live_compilation = true unless precompile_assets
      create_asset_plugin({:live_compilation => live_compilation})
      create_startup_script
      create_stop_script
    end
  end

  def excluded_groups
    (rails_env == "development") ? "test" : "test:development"
  end

  def rails_env
    if environment[:environment]
      rails_env_var = environment[:environment].find {|env| env =~ /\ARAILS_ENV=/}
      # Get value of RAILS_ENV without trailing quotes
      rails_env_var.strip.match(/^RAILS_ENV=('|")?(.*?)(\1)?$/)[2] if rails_env_var
    end
  end

  def stage_console
    #Copy cf-rails-console to app
    cf_rails_console_dir = destination_directory + '/app/cf-rails-console'
    FileUtils.mkdir_p(cf_rails_console_dir)
    FileUtils.cp_r(File.join(File.dirname(__FILE__), 'resources','cf-rails-console'),destination_directory + '/app')
    #Generate console access file for caldecott access
    config_file = cf_rails_console_dir + '/.consoleaccess'
    data = {'username' => UUIDTools::UUID.random_create.to_s,'password' => UUIDTools::UUID.random_create.to_s}
    File.open(config_file, 'w') do |fh|
      fh.write(YAML.dump(data))
    end
  end

  def startup_script
    vars = ruby_startup_vars
    vars['DISABLE_AUTO_CONFIG'] = 'mysql:postgresql'
    vars['RAILS_ENV'] = '${RAILS_ENV:-production}'
    generate_startup_script(vars) do
      cmds = ['mkdir ruby', 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb']
      if migration_enabled?
        cmds << <<-MIGRATE
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{migration_command} >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
        MIGRATE
      end
      cmds << <<-RUBY_CONSOLE
if [ -n "$VCAP_CONSOLE_PORT" ]; then
  cd app
  #{console_command} >>../logs/console.log 2>> ../logs/console.log &
  CONSOLE_STARTED=$!
  echo "$CONSOLE_STARTED" >> ../console.pid
  cd ..
fi
      RUBY_CONSOLE
      cmds.join("\n")
      end
  end

  def stop_script
    generate_stop_script
  end

  def stop_command
    cmds = []
    cmds << 'APP_PID=$1'
    cmds << 'APP_PPID=`ps -o ppid= -p $APP_PID`'
    cmds << 'kill -9 $APP_PID'
    cmds << 'kill -9 $APP_PPID'
    cmds << 'SCRIPT=$(readlink -f "$0")'
    cmds << 'SCRIPTPATH=`dirname "$SCRIPT"`'
    cmds << 'CONSOLE_PID=`head -1 $SCRIPTPATH/console.pid`'
    cmds << 'kill -9 $CONSOLE_PID'
    cmds.join("\n")
  end

  # Generates a trivial Rails plugin that re-enables static asset serving at boot, as
  # Rails applications often disable asset serving in production mode, and delegate that to
  # nginx or similar
  def create_asset_plugin(options)
    config = {"Rails.application.config.serve_static_assets" => "true"}
    if options[:live_compilation]
      logger.info("Turning on live assets compilation")
      config["Rails.application.config.assets.compile"] = "true"
    end
    init_code = config.map { |k,v| "#{k} = #{v}" }.join("\n")
    plugin_dir = File.join(app_dir, "vendor", "plugins", "configure_assets")
    FileUtils.mkdir_p(plugin_dir)
    init_script = File.join(plugin_dir, "init.rb")
    File.open(init_script, "wb") { |fh| fh.puts(init_code) }
    FileUtils.chmod(0600, init_script)
  end

  def rails_version
    rails_spec = gem_info("rails")
    rails_spec[:version]
  end

  def precompile_assets
    assets_manifest = File.join(app_dir, "public", "assets", "manifest.yml")
    if File.exists?(assets_manifest)
      logger.info("Skipping assets compilation, detected assets manifest")
      return true
    end
    assets_support_version = Gem::Version.new("3.1")
    if Gem::Version.new(rails_version) < assets_support_version
      logger.info("Skipping assets compilation, rails version does not support it")
      return true
    end

    logger.info("Running rake assets:precompile")
    Dir.mktmpdir do |tmp_dir|
      `cp -a #{app_dir}/. #{tmp_dir}`

      cmd = precompile_assets_command(tmp_dir)

      Dir.chdir(tmp_dir) do
        # TODO: set this correctly for all plugins
        @uid = @staging_uid
        @gid = @staging_gid
        exitstatus, output = run_secure(cmd, tmp_dir)
        if exitstatus == 0
          `cp -a #{tmp_dir}/. #{app_dir}`
          return true
        else
          logger.error("Assets precompilation failed: #{output}")
          return false
        end
      end
    end
  end
end
