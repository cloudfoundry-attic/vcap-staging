require "open3"
require "vcap/staging/plugin/shell_helpers"

class BuildpackInstaller < Struct.new(:buildpack, :app_dir, :logger)
  include ShellHelpers

  def detect
    logger.info "Checking #{buildpack.basename} ..."
    _, ok = run_and_log command('detect')
    logger.info "Skipping #{buildpack.basename}." unless ok
    ok
  end

  def compile
    logger.info "Installing #{buildpack.basename}."
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
    "#{buildpack}/bin/#{command_name} #{app_dir}"
  end
end