module RubyAutoconfig
  include GemfileSupport

  AUTO_CONFIG_GEM_NAME= 'cf-autoconfig'
  AUTO_CONFIG_GEM_VERSION= '0.0.4'
  #TODO Ideally we get transitive deps from cf-autoconfig gem, but this is no easy task
  #w/out downloading them every time
  AUTO_CONFIG_GEM_DEPS = [ ['cf-runtime', '0.0.2'] ]

  def autoconfig_enabled?
    cf_config_file =  destination_directory + '/app/config/cloudfoundry.yml'
    if File.exists? cf_config_file
      config = YAML.load_file(cf_config_file)
      if config && config['autoconfig'] == false
        return false
      end
    end
    if not uses_bundler?
       logger.warn "Auto-reconfiguration disabled because app does not use Bundler."
       logger.warn "Please provide a Gemfile.lock to use auto-reconfiguration."
       return false
    end
    #Return true if user has not explicitly opted out and they are not using cf-runtime gem
    return !(uses_cf_runtime?)
  end

  def install_autoconfig_gem
    install_local_gem File.join(File.dirname(__FILE__), 'resources'),"#{AUTO_CONFIG_GEM_NAME}-#{AUTO_CONFIG_GEM_VERSION}.gem"
    install_gems(AUTO_CONFIG_GEM_DEPS)
    #Add the autoconfig gem to the app's Gemfile
    File.open(destination_directory + '/app/Gemfile', 'a') {
        |f| f.puts("\n" + 'gem "cf-autoconfig"') }
  end

  def uses_cf_runtime?
    bundles_gem? 'cf-runtime'
  end

  def autoconfig_load_path
    return "-I#{gem_dir}/#{AUTO_CONFIG_GEM_NAME}-#{AUTO_CONFIG_GEM_VERSION}/lib" if autoconfig_enabled? && library_version == '1.8'
  end

  def gem_dir
    "$PWD/app/rubygems/ruby/#{library_version}/gems"
  end
end
