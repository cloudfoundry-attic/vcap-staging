require "logger"
require "fileutils"

require File.expand_path("../npm_cache", __FILE__)
require File.expand_path("../npm_package", __FILE__)
require File.expand_path("../../../git_cache", __FILE__)

module NpmSupport

  # If there is no npm-shwrinkwrap.json file don't do anything
  # Otherwise, install node modules according to npm-shwrinkwrap.json tree
  #
  # For each dependency in shrinkwrap tree recursively:
  # - If user provided module in node_modules folder
  #   - and it does not have native extensions skip it
  #   - and it has native extensions build it checking installed cache
  # - If module is not provided fetch it from registry checking fetched cache
  # or get from git cache
  #   - build it if it has native extensions checking installed cache
  #   - put it in node_modules folder according to npm-shrinkwrap.json tree

  def compile_node_modules
    # npm provided?
    return unless runtime[:npm]

    if @vcap_config["ignoreNodeModules"]
      logger.warn("ignoreNodeModules in cloudfoundry.json is deprecated, "+
        "native modules are detected automatically now")
    end

    @dependencies = get_dependencies
    return unless @dependencies

    cache_base_dir = StagingPlugin.platform_config["cache"]

    # Remove old caching directory
    FileUtils.rm_rf(File.join(cache_base_dir, "node_modules"))

    npm_cache_base_dir = File.join(cache_base_dir, "npm_cache")
    FileUtils.mkdir_p(File.join(npm_cache_base_dir))

    @cache = NpmCache.new(npm_cache_base_dir, runtime[:version], logger)
    @git_cache = GitCache.new(File.join(cache_base_dir, "git_cache"), nil, logger)

    logger.info("Installing dependencies. Node version #{runtime[:version]}")
    install_packages(@dependencies, app_directory)
  end

  def install_packages(dependencies, where)
    dependencies.each do |name, props|
      package_path = File.join(where, "node_modules", name)
      package = NpmPackage.new(name, props, package_path, @staging_uid,
                               @staging_gid, runtime, logger, @cache, @git_cache)
      installed_dir = package.install
      if installed_dir && props["dependencies"].is_a?(Hash)
        install_packages(props["dependencies"], installed_dir)
      end
    end
  end

  def get_dependencies
    shrinkwrap_file = File.join(app_directory, "npm-shrinkwrap.json")
    unless File.exists?(shrinkwrap_file)
      logger.info("Skipping npm support: npm-shrinkwrap.json is not provided")
      return nil
    end
    shrinkwrap_config = Yajl::Parser.parse(File.new(shrinkwrap_file, "r"))
    if shrinkwrap_config.is_a?(Hash) && shrinkwrap_config["dependencies"].is_a?(Hash)
      shrinkwrap_config["dependencies"]
    end
  end
end
