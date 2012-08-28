require "fileutils"
require "uri"
require File.expand_path("../../../secure_operations", __FILE__)

# Node module class
# Describes node module and performs operations: build, fetch and install
class NpmPackage
  include SecureOperations

  def initialize(name, props, where, secure_uid, secure_gid,
                 npm_helper, logger, cache, git_cache)
    @name  = name.chomp
    @target = (props["from"] || props["version"]).chomp
    @npm_helper = npm_helper
    @uid = secure_uid
    @gid = secure_gid
    @logger = logger
    @cache = cache
    @git_cache = git_cache
    @dst_dir = File.join(where, "node_modules", @name)
  end

  def install
    # Parsing source target according to npm source
    # (https://github.com/isaacs/npm/blob/master/lib/install.js#resolver):
    # If there is a "from" field use it as target
    # Else use "version" as target
    # If "version" starts with "http" or "git" it's a git URL
    # Else it is fetched from npm registry
    if url_provided?
      install_from_git
    else
      install_from_registry
    end
  end

  def install_from_git
    # We need to parse URL to get git repo URL and reference (commit SHA, tag, branch)
    begin
      parsed_url = URI(@target)
    rescue => e
      @logger.warn("Error parsing module source URL: #{e.message}")
      return nil
    end
    ref = parsed_url.fragment || "master"
    git_url = @target.sub(/#.*$/, "")

    fetched = fetch_from_git(git_url, ref)
    unless fetched
      @logger.warn("Failed fetching module #{@name}@#{@target} from Git source")
      return nil
    end

    # Unlike gemspec package.json does not provide information if module has native extensions
    # So we build everything
    installed = build(fetched)
    if installed
      return @dst_dir if copy_to_dst(installed)
    end
  end

  def install_from_registry
    cached = @cache.get(@name, @target)
    if cached
      return @dst_dir if copy_to_dst(cached)

    else
      @registry_data = get_registry_data

      unless @registry_data.is_a?(Hash) && @registry_data["version"]
        log_name = @target.empty? ? @name : "#{@name}@#{@target}"
        @logger.warn("Failed getting the requested package: #{log_name}")
        return nil
      end

      fetched = fetch_from_registry(@registry_data["source"])
      return unless fetched

      installed = build(fetched)

      if installed
        cached = @cache.put(installed, @name, @registry_data["version"])
        return @dst_dir if copy_to_dst(cached)
      end
    end
  end

  def fetch_from_git(uri, ref)
    tmp_dir = mk_temp_dir
    source = {}
    source[:uri] = uri
    source[:revision] = ref
    @git_cache.get_source(source, tmp_dir)
  end

  def fetch_from_registry(source)
    where = mk_temp_dir
    Dir.chdir(where) do
      fetched_tarball = "package.tgz"
      cmd = "wget --quiet --retry-connrefused --connect-timeout=5 " +
        "--no-check-certificate --output-document=#{fetched_tarball} #{source}"
      `#{cmd}`
      return unless $?.exitstatus == 0

      fetched_path = File.join(where, fetched_tarball)
      `tar xzf #{fetched_path} --directory=#{where} --strip-components=1 2>&1`
      return unless $?.exitstatus == 0
      FileUtils.rm_rf(fetched_path)

      File.exists?(where) ? where : nil
    end
  end

  def copy_to_dst(source)
    return unless source && File.exists?(source)
    FileUtils.rm_rf(@dst_dir)
    FileUtils.mkdir_p(@dst_dir)
    `cp -a #{source}/* #{@dst_dir}`
    $?.exitstatus == 0
  end

  def build(package_dir)
    cmd = @npm_helper.build_cmd(package_dir)
    cmd_status, output = run_secure(cmd, package_dir, :secure_group => true)

    if cmd_status != 0
      @logger.warn("Failed installing package: #{@name}")
      if output =~ /npm not ok/
        output.lines.grep(/^npm ERR! message/) do |error_message|
          @logger.warn(error_message.chomp)
        end
      end
    end
    cmd_status == 0 ? package_dir : nil
  end

  def get_registry_data
    # TODO: 1. make direct request, we need only tarball source
    # 2. replicate npm registry database
    package_link = "#{@name}@\"#{@target}\""
    output = `#{@npm_helper.versioner_cmd(package_link)} 2>&1`
    if $?.exitstatus != 0 || output.empty?
      return nil
    else
      begin
        resolved = Yajl::Parser.parse(output)
      rescue Exception=>e
        return nil
      end
    end
    resolved
  end

  private

  def url_provided?
    @target =~ /^http/ or @target =~ /^git/
  end

  def mk_temp_dir
    tmp_dir = Dir.mktmpdir
    at_exit do
      secure_delete(tmp_dir)
    end
    tmp_dir
  end
end
