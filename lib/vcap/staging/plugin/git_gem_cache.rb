require "digest/sha1"
require "fileutils"

class GitGemCache

  def initialize(directory)
    @directory  = directory
  end

  def put(revision, gem_name, installed_gem_path)
    return unless revision && gem_name
    return unless installed_gem_path && File.directory?(installed_gem_path)

    dst_dir = cached_obj_dir(revision, gem_name)

    # FIXME: use stdlib
    `cp -a #{installed_gem_path}/* #{dst_dir} && touch #{dst_dir}/.done`
    return installed_gem_path if $?.exitstatus != 0
    dst_dir
  end

  def get(revision, name)
    return nil unless revision && name
    dir = cached_obj_dir(revision, name)
    return nil if !File.exists?(File.join(dir, ".done"))
    File.directory?(dir) ? dir : nil
  end

  private

  def cached_obj_dir(revision, name)
    sha1 = Digest::SHA1.hexdigest("%s %s" % [revision, name])
    "%s/%s/%s/%s" % [ @directory, sha1[0..1], sha1[2..3], sha1[4..-1] ]
  end

end
