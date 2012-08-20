require "vcap/staging/plugin/git_cache"

describe GitCache do
  before :each do
    @cache_dir = Dir.mktmpdir
    @compiled_cache_dir = Dir.mktmpdir
    @working_dir = Dir.mktmpdir
    sha1 = Digest::SHA1.hexdigest("git://github.com/cloudfoundry/common.git")
    @uri_cache_dir = "%s/%s/%s/%s" % [ @cache_dir, sha1[0..1], sha1[2..3], sha1[4..-1] ]

    logger = double("Logger").as_null_object
    @cache = GitCache.new(@cache_dir, @compiled_cache_dir, logger)

    @source = {:uri => "git://github.com/cloudfoundry/common.git",
               :revision => "e36886a189b82f880a5aa3e9169712d5d9048a88"}

    @source_dir = @cache.get_source(@source, @working_dir)
  end

  after :each do
    FileUtils.rm_rf(@cache_dir) if @cache_dir
    FileUtils.rm_rf(@compiled_cache_dir) if @compiled_cache_dir
    FileUtils.rm_rf(@working_dir) if @working_dir
  end

  it "should create cache dir for url" do
    Pathname.new(@uri_cache_dir).should be_directory
  end

  it "should provide the source of requested revision" do
    Dir.chdir(@source_dir) do
      head_revision = `git rev-parse HEAD`
      head_revision.strip.should == @source[:revision]
    end
  end

  it "should use cache" do
    Dir.mktmpdir do |new_working_dir|
      fetched_path = @cache.get_source(@source, new_working_dir)
      Dir.chdir(fetched_path) do
        origin = `git remote show origin`
        origin.should match /#{@uri_cache_dir}/
      end
    end
  end

  it "should update cache when revision is not found" do
    check_file = File.join(@uri_cache_dir, "FETCH_HEAD")
    FileUtils.rm_f(check_file)
    @source[:revision] = "a" * 40
    @cache.get_source(@source, @working_dir)
    File.exists?(check_file).should be true
  end

  it "should put gem into compiled cache" do
    @cache.put_compiled_gem(@source_dir, @source[:revision])
    cached_path = File.join(@compiled_cache_dir, @source[:revision][0..1], @source[:revision][2..-1])
    File.exists?(cached_path).should be true
  end

  it "should get gem from compiled cache" do
    @cache.put_compiled_gem(@source_dir, @source[:revision])
    cached_path = File.join(@compiled_cache_dir, @source[:revision][0..1], @source[:revision][2..-1])
    path = @cache.get_compiled_gem(@source[:revision])
    path.should == cached_path
  end
end