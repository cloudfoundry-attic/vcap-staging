require "digest/sha1"
require "fileutils"
require "uri"
require "tmpdir"

class GitCache

  def initialize(repo_dir, compiled_gems_dir, logger)
    @repo_dir = repo_dir
    @compiled_gems_dir = compiled_gems_dir
    @logger = logger
  end

  # Clone a cached source to destination and reset to given revision
  def get_source(source, dst_dir)
    return unless source[:uri] && source[:revision]
    uri = normalize_uri(source[:uri])
    revision = source[:revision].strip
    # Check that revision follows git-check-ref-format
    return unless revision =~ /^[a-z0-9_\-\/\.]*[a-z0-9_\-]$/

    cached_path = find_source(uri, revision)
    return unless cached_path && File.directory?(cached_path)
    exitstatus = run_cmd_with_retry("git clone --no-hardlinks -q #{cached_path} #{dst_dir}")
    return if exitstatus != 0

    Dir.chdir(dst_dir) do
      `git reset --hard #{revision}`
      return if $?.exitstatus != 0
      `git submodule update --init --recursive` if (source[:submodules])
    end

    dst_dir
  end

  def get_compiled_gem(revision)
    path = compiled_gem_path(revision)
    File.directory?(path) ? path : nil
  end

  def put_compiled_gem(source, revision)
    return unless source && File.exists?(source)
    dst = compiled_gem_path(revision)
    return if File.exists?(dst)
    FileUtils.mkdir_p(File.dirname(dst))
    begin
      File.rename(source, dst)
    rescue => e
      @logger.debug("Failed putting into cache: #{e}")
      return nil
    end

    dst
  end

  private

  def run_cmd_with_retry(cmd)
    `#{cmd}`
    exitstatus = $?.exitstatus
    if exitstatus != 0
      # Someone else was updating repo? (see double rename in update_git_cache)
      sleep(0.1)
      `#{cmd}`
      exitstatus = $?.exitstatus
    end
    exitstatus
  end

  def update_git_cache(uri)
    cache_dir = cached_git_source_dir(uri)
    tmp_dir = Dir.mktmpdir
    cache_rename_dir = Dir.mktmpdir
    begin
      exitstatus = run_cmd_with_retry("cp -a #{cache_dir}/* #{tmp_dir}")
      return nil if exitstatus != 0
      `git --git-dir=#{tmp_dir} remote update`
      return nil if $?.exitstatus != 0

      # Updating repo, this can break copying and cloning that happen at the same time
      File.rename(cache_dir, cache_rename_dir)
      File.rename(tmp_dir, cache_dir)
    ensure
      FileUtils.remove_entry_secure(cache_rename_dir) if File.exists?(cache_rename_dir)
      FileUtils.remove_entry_secure(tmp_dir) if File.exists?(tmp_dir)
    end
  end

  def cached_obj_available?(where, revision)
    system("git --git-dir=#{where} cat-file -e #{revision}")
  end

  def create_git_cache_source_dir(where, source)
    tmp_dir = Dir.mktmpdir
    begin
      `git clone --mirror --no-hardlinks -q #{source} #{tmp_dir}`
      raise "Failed cloning gem from source: #{source}" if $?.exitstatus != 0
      begin
        FileUtils.rm_rf(where)
        FileUtils.mkdir_p(where)
        File.rename(tmp_dir, where)
      rescue => e
        # Someone else created repo already?
        @logger.debug("Failed creating git cache dir #{where}: #{e.message}")
      end
    ensure
      FileUtils.remove_entry_secure(tmp_dir) if File.exists?(tmp_dir)
    end
  end

  # Get a path to cached git repo with given revision
  def find_source(uri, revision)
    return nil unless uri
    dir = cached_git_source_dir(uri)
    found_path = nil
    latest = false

    unless File.directory?(dir) && git_repository?(dir)
      # Need to create git cache repo
      create_git_cache_source_dir(dir, uri)
      latest = true
    end

    until found_path do
      if cached_obj_available?(dir, revision)
        found_path = dir
      else
        # Revision was not found in latest repo
        return nil if latest
        update_git_cache(uri)
        latest = true
      end
    end
    found_path
  end

  def git_repository?(where)
    system("git --git-dir=#{where} rev-parse")
  end

  def cached_git_source_dir(uri)
    sha1 = Digest::SHA1.hexdigest(uri)
    "%s/%s/%s/%s" % [ @repo_dir, sha1[0..1], sha1[2..3], sha1[4..-1] ]
  end

  def normalize_uri(uri)
    # Downcase the domain component and remove trailing slash
    URI.parse(uri).normalize.to_s.sub(%r{/$}, "")
  end

  def compiled_gem_path(revision)
    File.join(@compiled_gems_dir, revision[0..1], revision[2..-1])
  end
end
