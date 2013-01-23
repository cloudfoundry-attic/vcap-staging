require "open3"
require "vcap/staging/plugin/shell_helpers"

class BuildpackInstaller < Struct.new(:path, :app_dir, :logger)
  include ShellHelpers

  def detect
    logger.info "Checking #{path.basename} ..."
    @detect_output, status = Open3.capture2 command('detect')
    logger.info "Skipping #{path.basename}." unless status == 0
    status == 0
  end

  def name
    @detect_output ? @detect_output.strip : nil
  end

  def compile
    logger.info "Installing #{path.basename}."
    output, ok = run_and_log "#{command('compile')} /tmp/bundler_cache"
    raise "Buildpack compilation step failed:\n#{output}" unless ok
  end

  def release_info
    output, status = Open3.capture2 command("release")
    raise "Release info failed:\n#{output}" unless status == 0
    YAML.load(output)
  end



  private

  def command(command_name)
    "#{path}/bin/#{command_name} #{app_dir}"
  end
end