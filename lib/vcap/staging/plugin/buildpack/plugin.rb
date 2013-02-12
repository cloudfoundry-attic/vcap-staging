require 'bundler'

require 'vcap/staging/plugin/rails3/database_support'
require "uuidtools"
require_relative("buildpack_installer")

class BuildpackPlugin < StagingPlugin
  include RailsDatabaseSupport

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      FileUtils.chmod_R(0744, app_dir)
      Bundler.with_clean_env do
        build_pack.compile
      end
      stage_rails_console if rails_buildpack?
      create_startup_script
    end
  end

  def clone_buildpack(buildpack_url)
    buildpack_path = "#{app_dir}/.buildpacks/#{File.basename(buildpack_url)}"
    ok = system("git clone #{buildpack_url} #{buildpack_path}")
    raise "Failed to git clone buildpack" unless ok
    BuildpackInstaller.new(Pathname.new(buildpack_path), app_dir)
  end

  def build_pack
    return @build_pack if @build_pack

    custom_url = environment[:buildpack]
    return @build_pack = clone_buildpack(custom_url) if custom_url

    @build_pack = installers.detect(&:detect)
    raise "Unable to detect a supported application type" unless @build_pack

    @build_pack
  end

  def buildpacks_path
    Pathname.new(__FILE__) + '../../../../../../vendor/buildpacks/'
  end

  def installers
    buildpacks_path.children.map do |buildpack|
      BuildpackInstaller.new(buildpack, app_dir)
    end
  end

  def start_command
    return environment[:meta][:command] if environment[:meta] && environment[:meta][:command]
    procfile["web"] ||
      release_info.fetch("default_process_types", {})["web"] ||
        raise("Please specify a web start command in your manifest.yml or Procfile")
  end

  def procfile
    @procfile ||= procfile_contents ? YAML.load(procfile_contents) : {}
    raise "Invalid Procfile format.  Please ensure it is a valid YAML hash" unless @procfile.kind_of?(Hash)
    @procfile
  end

  def procfile_contents
    procfile_path = "#{app_dir}/Procfile"

    File.read(procfile_path) if File.exists?(procfile_path)
  end

  # TODO - remove this when we have the ability to ssh to a locally-running console
  def rails_buildpack?
    @build_pack.name == "Ruby/Rails"
  end

  def stage_rails_console
    #Copy cf-rails-console to app
    cf_rails_console_dir = app_dir + '/cf-rails-console'
    FileUtils.mkdir_p(cf_rails_console_dir)
    FileUtils.cp_r(File.expand_path('../resources/cf-rails-console', __FILE__), app_dir)
    #Generate console access file for caldecott access
    config_file = cf_rails_console_dir + '/.consoleaccess'
    data = {'username' => UUIDTools::UUID.random_create.to_s,'password' => UUIDTools::UUID.random_create.to_s}
    File.open(config_file, 'w') do |fh|
      fh.write(YAML.dump(data))
    end
  end

  def startup_script
    generate_startup_script(environment_variables) do
      script_content = <<-BASH
unset GEM_PATH
if [ -d app/.profile.d ]; then
  for i in app/.profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
env > logs/env.log
BASH

      if rails_buildpack?
        script_content += <<-BASH
if [ -n "$VCAP_CONSOLE_PORT" ]; then
  cd app
  bundle exec ruby cf-rails-console/rails_console.rb >> ../logs/console.log 2>> ../logs/console.log &
  CONSOLE_STARTED=$!
  echo "$CONSOLE_STARTED" >> ../console.pid
  cd ..
fi
        BASH
      end

      script_content
    end
  end

  def release_info
    build_pack.release_info
  end

  def environment_variables
    vars = release_info['config_vars'] || {}
    vars.each { |k, v| vars[k] = "${#{k}:-#{v}}" }
    vars["HOME"] = "$PWD/app"
    vars["PORT"] = "$VCAP_APP_PORT"
    vars["DATABASE_URL"] = database_uri if rails_buildpack? && bound_database
    vars["MEMORY_LIMIT"] = "#{application_memory}m"
    vars
  end
end