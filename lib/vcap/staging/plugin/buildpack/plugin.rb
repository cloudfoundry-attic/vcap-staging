require 'bundler'
require 'vcap/staging/plugin/rails3/database_support'
require_relative("buildpack_installer")

class BuildpackPlugin < StagingPlugin
  include RailsDatabaseSupport

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      Bundler.with_clean_env do
        build_pack.compile
      end
      create_startup_script
    end
  end

  def build_pack
    @build_pack ||= installers.detect(&:detect)
    raise "Unable to detect a supported application type" unless @build_pack
    @build_pack
  end

  def buildpacks_path
    Pathname.new(__FILE__) + '../../../../../../vendor/buildpacks/'
  end

  def installers
    buildpacks_path.children.map do |buildpack_path|
      BuildpackInstaller.new(buildpack_path.basename, buildpack_path, app_dir, logger)
    end
  end

  def start_command
    procfile["web"] || release_info.fetch("default_process_types", {})["web"] ||
        raise("Please specify a web start command using a Procfile")
  end

  def procfile
    @procfile ||= procfile_contents ? YAML.load(procfile_contents) : {}
    raise "Invalid Procfile format.  Please ensure it is a valid YAML hash" unless @procfile.kind_of?(Hash)
    @procfile
  end

  def procfile_contents
    procfile_path = 'Procfile'

    File.read(procfile_path) if File.exists?(procfile_path)
  end

  def app_dir
    destination_directory
  end

  def tmp_dir
    File.join(destination_directory, ".cloudfoundry", "tmp")
  end

  def script_dir
    File.join(destination_directory, ".cloudfoundry")
  end

  def pidfile_dir
    File.join("$DROPLET_BASE_DIR",".cloudfoundry")
  end

  def change_directory_for_start
    ""
  end

  def startup_script
    generate_startup_script(environment_variables) do
      <<-BASH
unset GEM_PATH
if [ -d .profile.d ]; then
  for i in .profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
env > logs/env.log
BASH
    end
  end

  def release_info
    build_pack.release_info
  end

  def environment_variables
    vars = release_info['config_vars']
    vars.each { |k, v| vars[k] = "${#{k}:-#{v}}" }
    vars["PORT"] = "$VCAP_APP_PORT"
    vars["DATABASE_URL"] = database_uri if bound_database
    vars["MEMORY_LIMIT"] = "#{application_memory}m"
    vars
  end
end