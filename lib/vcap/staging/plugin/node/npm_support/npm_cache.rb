require "fileutils"

class NpmCache
  def initialize(base_dir, library_version, logger)
    # fetched contains fetched from registry by module name and version
    @fetched_cache_dir = File.join(base_dir, "fetched")
    FileUtils.mkdir_p(@fetched_cache_dir)

    # installed_cache_dir contains modules with extensions after npm install
    # by module directory hash and specific node version
    @installed_cache_dir  = File.join(base_dir, "installed", library_version)
    FileUtils.mkdir_p(@installed_cache_dir)

    @logger = logger
  end

  def put_fetched(source, name, version)
    dir = File.join(@fetched_cache_dir, name, version)
    package_path = File.join(dir, "package")
    put(source, package_path)
  end

  def get_fetched(name, version)
    dir = File.join(@fetched_cache_dir, name, version)
    package_path = File.join(dir, "package")
    File.directory?(package_path) ? package_path : nil
  end

  def get_installed(package_hash)
    package_path = installed_path(package_hash)
    File.directory?(package_path) ? package_path : nil
  end

  def put_installed(package_hash, source)
    package_path = installed_path(package_hash)
    put(source, package_path)
  end

  private

  def put(source, dest)
    return unless source && File.exists?(source)
    return if File.exists?(dest)
    FileUtils.mkdir_p(File.dirname(dest))
    begin
      File.rename(source, dest)
    rescue => e
      @logger.debug("Failed putting into cache: #{e}")
      return nil
    end
    dest
  end

  def installed_path(hash)
    File.join(@installed_cache_dir, hash[0..1], hash[2..3], hash[4..-1])
  end
end
