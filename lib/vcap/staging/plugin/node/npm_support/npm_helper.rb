require "shellwords"

class NpmHelper

  attr_accessor :npm_version

  def initialize(node_path, node_version, npm_path, uid, gid)
    @node_path = node_path
    @node_version = node_version
    @npm_path = npm_path
    @npm_version = get_npm_version
    @uid = uid
    @gid = gid
  end

  def get_npm_version
    version = `#{npm_cmd} -v 2>&1`
    return version.chomp if $?.exitstatus == 0
  end

  def node_safe_env
    env_vars = [ "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "C_INCLUDE_PATH", "LIBRARY_PATH" ]
    safe_env = env_vars.map { |e| "#{e}='#{ENV[e]}'" }.join(" ")
    safe_env << " LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"
    safe_env << " PATH=#{File.dirname(@node_path)}:$PATH"
    safe_env
  end

  def npm_cmd
    if @npm_path =~ /\.js$/
      "#{node_safe_env} #{@node_path} #{@npm_path}"
    else
      "#{node_safe_env} #{@npm_path}"
    end
  end

  def npm_flags
    cmd = "--production true --color false --loglevel error --non-global true --force true"
    cmd += " --user #{@uid}" if @uid
    cmd += " --group #{@gid}" if @gid
    cmd
  end

  def build_cmd(where)
    "#{npm_cmd} build #{where} #{npm_flags} 2>&1"
  end

  def install_cmd(package, where, cache_dir, tmp_dir)
    "#{npm_cmd} install #{shellescape(package)} --prefix #{where} #{npm_flags} " +
      "--cache #{cache_dir} --tmp #{tmp_dir} --node_version #{@node_version} " +
      "--registry http://registry.npmjs.org/"
  end

  def versioner_cmd(node_range, npm_range)
    versioner_path = File.expand_path("../../resources/versioner/versioner.js", __FILE__)
    "#{node_safe_env} #{@node_path} #{versioner_path} --node-range=#{shellescape(node_range.to_s)}" +
    " --npm-range=#{shellescape(npm_range.to_s)} --node-version=#{shellescape(@node_version)}" +
    " --npm-version=#{@npm_version}"
  end

  def fetch_cmd(source, dst)
    "wget --quiet --retry-connrefused --connect-timeout=5 " +
    "--no-check-certificate --output-document=#{dst} #{shellescape(source)}"
  end

  def unpack_cmd(what, where)
    "tar xzf #{what} --directory=#{where} --strip-components=1 2>&1"
  end

  def shellescape(word)
    Shellwords.escape(word)
  end
end
