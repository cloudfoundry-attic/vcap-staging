require "shellwords"

module NodeAutoconfig

  def autoconfig_enabled?
    @vcap_config["cfAutoconfig"] != false && !uses_cf_runtime?
  end

  def uses_cf_runtime?
    !Dir.glob(File.join(app_directory, "**", "cf-runtime", "package.json")).empty?
  end

  def autoconfig_bootstrap_file
    "autoconfig.js"
  end

  def autoconfig_source_file
    File.join(File.dirname(__FILE__), "resources", autoconfig_bootstrap_file)
  end

  def autoconfig_module_dir
    File.join(File.dirname(__FILE__), "resources", "node_modules", "cf-autoconfig")
  end

  def setup_autoconfig
    # only change first argument if start command has several
    args = Shellwords.split(detect_start_command)
    @main_file = args[0]
    args[0] = autoconfig_bootstrap_file
    @autoconfig_start_command = Shellwords.join(args)

    provide_autoconfig_module
    setup_start_script
    @autoconfigured = true
  end

  def provide_autoconfig_module
    # put module in base node_modules, node will find it here
    node_modules_dir = File.join(app_directory, "node_modules")
    FileUtils.mkdir_p(node_modules_dir) unless File.exists?(node_modules_dir)
    FileUtils.cp_r(autoconfig_module_dir, node_modules_dir)
  end

  def setup_start_script
    FileUtils.cp(autoconfig_source_file, app_directory)
    bootstrap_source = File.read(autoconfig_source_file)
    bootstrap_source.gsub!(/@@MAIN_FILE@@/, @main_file)

    File.open(File.join(app_directory, autoconfig_bootstrap_file), "w") do |f|
      f.puts(bootstrap_source)
    end
  end
end
