class BuildpackInstaller < Struct.new(:buildpack, :buildpack_path, :app_dir, :logger)
  include SecureOperations

  def detect
    logger.info "Checking #{buildpack} ..."
    _, ok = run_and_check command('detect')
    logger.info "Skipping #{buildpack}." unless ok
    ok
  end

  def compile
    logger.info "Installing #{buildpack}."
    output, ok = run_and_check "#{command('compile')} /tmp/bundler_cache"
    raise "Buildpack compilation step failed:\n#{output}" unless ok
  end

  def release_info
    output, ok = run_and_check command('release')
    raise "Release info failed:\n#{output}" unless ok
    YAML.load(output)
  end

  private

  def command(command_name)
    "#{buildpack_path}/bin/#{command_name} #{app_dir}"
  end

  def run_and_check(command)
    output = `#{command}`
    return_code = $? == 0
    logger.info output
    [output, return_code]
  end
end