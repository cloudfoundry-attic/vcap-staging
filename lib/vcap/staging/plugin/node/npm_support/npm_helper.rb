require "shellwords"

module NpmHelper
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

  def run_build(where)
    cmd = "#{npm_cmd} build #{where} #{npm_flags} 2>&1"
    run_secure(cmd, where, :secure_group => true)
  end

  def verify_engine_versions(node_range, npm_range)
    # Using node module semver to validate node and npm requirements
    versioner_path = File.expand_path("../../resources/versioner/versioner.js", __FILE__)
    cmd = "#{node_safe_env} #{@node_path} #{versioner_path} --node-range=#{shellescape(node_range.to_s)}"
    cmd += " --npm-range=#{shellescape(npm_range.to_s)} --node-version=#{shellescape(@node_version)}"
    cmd += " --npm-version=#{@npm_version}"
    output = `#{cmd} 2>&1`

    [$?.exitstatus, output]
  end

  def fetch(source, dst)
    cmd = "wget --quiet --retry-connrefused --connect-timeout=5 " +
      "--no-check-certificate --output-document=#{dst} #{shellescape(source)}"
    `#{cmd}`
    $?.exitstatus
  end

  def unpack(what, where)
    cmd = "tar xzf #{what} --directory=#{where} --strip-components=1 2>&1"
    `#{cmd}`
    $?.exitstatus
  end

  def shellescape(word)
    Shellwords.escape(word)
  end
end
