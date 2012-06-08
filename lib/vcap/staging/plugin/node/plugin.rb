require File.expand_path("../npm_support/npm_support", __FILE__)
require File.expand_path("../node_autoconfig", __FILE__)

class NodePlugin < StagingPlugin
  include NpmSupport
  include NodeAutoconfig

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      read_configs
      compile_node_modules
      setup_autoconfig if autoconfig_enabled?
      create_startup_script
      create_stop_script
    end
  end

  # Let DEA fill in as needed..
  def start_command
    command = @autoconfigured ? @autoconfig_start_command : detect_start_command
    "%VCAP_LOCAL_RUNTIME% $NODE_ARGS #{command} $@"
  end

  private

  def detect_start_command
    package_json_start || guess_main_file
  end

  def app_directory
    File.expand_path(File.join(destination_directory, "app"))
  end

  def startup_script
    generate_startup_script
  end

  def stop_script
    generate_stop_script
  end

  def read_configs
    package = File.join(app_directory, "package.json")
    if File.exists?(package)
      @package_config = Yajl::Parser.parse(File.new(package, "r"))
    end
    @vcap_config = {}
    vcap_config_file = File.join(app_directory, "cloudfoundry.json")
    if File.exists?(vcap_config_file)
      config = Yajl::Parser.parse(File.new(vcap_config_file, "r"))
      @vcap_config = config if config.is_a?(Hash)
    end
  end

  # detect start script from package.json
  def package_json_start
    if @package_config.is_a?(Hash) &&
        @package_config["scripts"].is_a?(Hash) &&
        @package_config["scripts"]["start"]
      @package_config["scripts"]["start"].sub(/^\s*node\s+/, "")
    end
  end

  def guess_main_file
    file = nil
    js_files = app_files_matching_patterns

    if js_files.length == 1
      file = js_files.first
    else
      %w{server.js app.js index.js main.js application.js}.each do |fname|
        file = fname if js_files.include? fname
      end
    end

    # TODO - Currently staging exceptions are not handled well.
    # Convert to using exit status and return value on a case-by-case basis.
    raise "Unable to determine Node.js startup command" unless file
    file
  end
end
