class BuildpackInstaller < Struct.new(:buildpack, :buildpack_path, :app_dir, :logger)
  include SecureOperations

  def detect
    logger.info "Checking #{buildpack} ..."
    if system(command('detect'))
      true
    else
      logger.info "Skipping #{buildpack}."
      false
    end
  end

  def compile
    logger.info "Installing #{buildpack}."
    output = `#{command('compile')} /tmp/bundler_cache`
    return_code = $?
    logger.info output
    raise "Buildpack compilation step failed:\n#{output}" unless return_code == 0
  end

  def release_info
    Bundler.with_clean_env do
      release_info_yml = `#{command('release')}`
      raise "Release info failed: #{release_info_yml}" unless $? == 0
      YAML.load(release_info_yml)
    end
  end

  def command(command_name)
    "#{buildpack_path}/bin/#{command_name} #{app_dir}"
  end
end