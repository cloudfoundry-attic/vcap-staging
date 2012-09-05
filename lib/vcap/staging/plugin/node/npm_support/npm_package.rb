require "fileutils"
require "uri"
require "net/http"
require File.expand_path("../../../secure_operations", __FILE__)
require File.expand_path("../npm_helper", __FILE__)

# Node module class
# Describes node module and performs operations: build, fetch and install
class NpmPackage
  include SecureOperations
  include NpmHelper

  def initialize(name, props, package_path, secure_uid, secure_gid,
                 runtime, logger, cache, git_cache)
    @name  = name.chomp
    # Parsing source target according to npm source
    # (https://github.com/isaacs/npm/blob/master/lib/install.js#resolver):
    # If there is a "from" field use it as target
    # Else use "version" as target
    @target = (props["from"] || props["version"]).chomp
    @display_name = "#{@name}@#{@target}"
    @uid = secure_uid
    @gid = secure_gid
    @logger = logger
    @cache = cache
    @git_cache = git_cache
    @package_path = package_path
    @node_path = runtime[:executable]
    @node_version = runtime[:version]
    @npm_path = runtime[:npm]
    @npm_version = get_npm_version
  end

  def install
    if File.exists?(@package_path)
      @logger.info("Installing #{@display_name} from local path")
      # If module is provided and it has native extensions build it
      # It it does not have native extensions skip it
      if has_native_extensions?(@package_path)
        return install_copy_from_path(@package_path)
      else
        return @package_path
      end
    else
      if url_provided?
        @logger.info("Installing #{@display_name} from git source")
        Dir.mktmpdir do |where|
          fetched = fetch_from_git(where)
          return unless fetched
          if has_native_extensions?(fetched)
            install_from_path(fetched)
          else
            return @package_path if copy_to_dst(fetched)
          end
        end
      else
        @logger.info("Installing #{@display_name} from registry")
        cached = get_cached_from_registry
        return unless cached
        if has_native_extensions?(cached)
          return install_copy_from_path(cached)
        else
          return @package_path if copy_to_dst(cached)
        end
      end
    end
  end

  def install_from_path(package_path)
    return unless engine_version_satisfied?(package_path)
    package_hash = clean_package_hash(package_path)
    cached = @cache.get_installed(package_hash)
    if cached
      return @package_path if copy_to_dst(cached)
    else
      installed = build(package_path)
      if copy_to_dst(installed)
        @cache.put_installed(package_hash, installed)
        return @package_path
      end
    end
  end

  def install_copy_from_path(package_path)
    begin
      tmp_dir = Dir.mktmpdir
      FileUtils.copy_entry(package_path, tmp_dir, true, nil, true)
      install_from_path(tmp_dir)
    ensure
      FileUtils.rm_rf(tmp_dir)
    end
  end

  def fetch_from_git(dst_path)
    # Parse URL to get git repo URL and reference (commit SHA, tag, branch)
    begin
      parsed_url = URI(@target)
    rescue => e
      @logger.warn("Error parsing module source URL: #{e.message}")
      return nil
    end
    source = {}
    source[:uri] = @target.sub(/#.*$/, "")
    source[:revision] = parsed_url.fragment || "master"
    fetched = @git_cache.get_source(source, dst_path)
    unless fetched
      @logger.warn("Failed fetching module #{@display_name} from Git source")
      return nil
    end

    fetched
  end

  def fetch_from_registry(dst_path)
    Dir.chdir(dst_path) do
      registry_data = get_registry_data
      unless registry_data.is_a?(Hash) && registry_data["version"] &&
          registry_data["dist"] && registry_data["dist"]["tarball"]
        @logger.warn("Failed getting the requested package: #{@display_name}")
        return nil
      end

      source = registry_data["dist"]["tarball"]
      fetched_tarball = "package.tgz"
      fetch_status = fetch(source, fetched_tarball)
      unless fetch_status == 0
        @logger.warn("Failed fetching module #{@display_name} from npm registry")
        return nil
      end

      fetched_tarball_path = File.join(dst_path, fetched_tarball)
      unpack_status = unpack(fetched_tarball_path, dst_path)
      FileUtils.rm_rf(fetched_tarball_path)
      if unpack_status == 0
        return dst_path
      else
        @logger.warn("Failed extracting fetched module #{@display_name}")
        return nil
      end
    end
  end

  def get_cached_from_registry
    cached = @cache.get_fetched(@name, @target)
    return cached if cached

    begin
      tmp_dir = Dir.mktmpdir
      fetched = fetch_from_registry(tmp_dir)
      if fetched
        cached = @cache.put_fetched(tmp_dir, @name, @target)
      end
    ensure
      FileUtils.rm_rf(tmp_dir)
    end

    return cached
  end

  def copy_to_dst(source)
    return unless source && File.exists?(source)
    FileUtils.rm_rf(@package_path)
    FileUtils.mkdir_p(File.dirname(@package_path))
    begin
      FileUtils.copy_entry(source, @package_path)
      return true
    rescue => e
      @logger.debug("Failed copying module to application #{e.message}")
      return false
    end
  end

  def build(where)
    cmd_status, output = run_build(where)
    if cmd_status != 0
      @logger.error("Failed building package: #{@display_name}")
      @logger.error(output) if output
    end
    cmd_status == 0 ? where : nil
  end

  def get_registry_data
    # TODO: replicate npm registry database
    npm_registry_url = URI("http://registry.npmjs.org/#{@name}/#{@target}")
    begin
      res = Net::HTTP.get_response(npm_registry_url)
    rescue Timeout::Error
      @logger.error("Timeout error requesting npm registry #{@display_name}")
      return nil
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection then
      begin
        package_data = Yajl::Parser.parse(res.body)
        return package_data
      rescue => e
        @logger.error("Failed parsing requested data from npm registry #{@display_name}")
        return nil
      end
    when Net::HTTPNotFound then
      @logger.error("Package is not found in npm registry #{@display_name}")
      return nil
    else
      @logger.error("Error requesting npm registry for #{@display_name} #{res.code}")
      return nil
    end
  end

  # Verifies if package engine requirements are satisfied
  def engine_version_satisfied?(package_path)
    config = package_config(File.join(package_path, "package.json"))
    return true unless config && config["engines"]
    if config["engines"]["node"] || config["engines"]["npm"]
      status, output = verify_engine_versions(config["engines"]["node"], config["engines"]["npm"])
      if status == 0
        return true
      else
        @logger.error("Failed installing #{@display_name}: #{output}")
        return nil
      end
    end
  end

  def has_native_extensions?(where)
    pattern = File.join("**", "{binding.gyp,*.{node,c,cc}}")
    Dir.glob(File.join(where, pattern)).size > 0
  end

  def clean_package_hash(where)
    clean_package(where)
    dir_hash(where)
  end

  def package_config(config_file)
    begin
      package_config = Yajl::Parser.parse(File.new(config_file, "r"))
      return package_config
    rescue => e
      @logger.error("Failed parsing package.json of #{@display_name}")
      return nil
    end
  end

  # This is trying to revert package to state before npm install was run on it
  # 1. Remove npm information from package.json
  # 2. Remove installation results
  def clean_package(where)
    # Remove arbitrary information from package.json
    config_file = File.join(where, "package.json")
    config = package_config(config_file)
    return unless config
    # Remove all elements that start with underscore (added by npm install)
    config.reject! { |key, _| key =~ /^_/}
    File.open(config_file, "w+") { |f| f.write(Yajl::Encoder.encode(config)) }

    # Remove build files
    FileUtils.rm_f(File.join(where, ".lock-wscript"))
    FileUtils.rm_rf(File.join(where, "build"))
    FileUtils.rm_rf(File.join(where, "node_modules"))
    pattern = File.join("**", "*.{node,o}")
    Dir.glob(File.join(where, pattern)) { |file| File.rm_f(file) }
  end

  # Generate consistent hash of the directory
  # Sorting filenames first to detect if file was moved,
  # and hashing the list of all file contents hashes
  def dir_hash(where)
    `find #{where} -type f | sort -f | xargs shasum | awk '{print $1}' | shasum | awk '{print $1}'`.strip
  end

  def url_provided?
    @target =~ /^http/ || @target =~ /^git/
  end
end
