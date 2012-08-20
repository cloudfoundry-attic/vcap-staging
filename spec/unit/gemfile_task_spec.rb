require "spec_helper"
require "vcap/staging/plugin/gemfile_task"

describe "GemfileTask" do

  before :each do
    @ruby_cmd = ENV["VCAP_RUNTIME_RUBY19"] || "ruby"
    @working_dir = Dir.mktmpdir
    @app_dir = File.join(@working_dir, "app")
    FileUtils.mkdir(@app_dir)
    @bundler_gems_dir = File.join(@app_dir, "rubygems", "ruby", "1.9.1", "bundler", "gems")
    @git_working_dir = Dir.mktmpdir
  end

  after :each do
    FileUtils.rm_rf(@working_dir)
    FileUtils.rm_rf(@git_working_dir)
  end

  describe "Sinatra app with git dependencies" do
    before :each do
      test_app = app_fixture_base_directory.join("sinatra_git", "source")
      FileUtils.cp_r(File.join(test_app, "."), @app_dir)

      @git_gems = %w(eventmachine vcap_logging)

      @task = GemfileTask.new(@app_dir, "1.9.1", @ruby_cmd, @working_dir)
    end

    it "should include git gems in specs" do
      @task.specs.select { |s|
        s[:source][:type] == "Bundler::Source::Git"
      }.map { |s|
        s[:name]
      }.sort.should == @git_gems
    end

    it "should install git gems from git and not rubygems" do
      installed_git_gems = []
      @task.stub(:install_gem) do |name, version|
        @git_gems.should_not include name
      end
      @task.stub(:install_git_gem) do |spec|
        installed_git_gems << spec[:name]
      end
      @task.install
      installed_git_gems.should == @git_gems
    end

    it "should fail if revision is not specified" do
      spec = {:name => "vcap_logging", :version => "1.0.2",
              :source => {:url => "git://github.com/cloudfoundry/common.git"}}
      lambda {
        @task.install_git_gem(spec)
      }.should raise_error
    end

    it "should put git gems in bundler path" do
      @task.instance_variable_get(:@git_cache).stub(:get_source) { |source, where| where }
      @task.stub(:install_gem)
      @task.stub(:build_gem) { |path| "#{File.basename(path)}.gem" }
      @task.stub(:compile_gem) { |path| path }
      @task.install
      Pathname.new(File.join(@bundler_gems_dir, "common-e36886a189b8")).should be_directory
      Pathname.new(File.join(@bundler_gems_dir, "eventmachine-2806c630d863")).should be_directory
    end
  end

  describe "#install_git_gem" do
    before :each do
      test_gem = app_fixture_base_directory.join("sinatra_git", "test_gem")
      FileUtils.cp_r(test_gem, @git_working_dir)
      @spec = {:name => "hello", :version => "0.0.1",
              :source => {:url => "url",
                          :revision => "revision",
                          :git_scope => "git_scope"}}
      @task = GemfileTask.new(@app_dir, "1.9.1", @ruby_cmd, @working_dir)
      @task_git_cache = @task.instance_variable_get(:@git_cache)
      @task_git_cache.stub(:get_source) do |source, where|
        File.join(@git_working_dir, "test_gem")
      end
      @task_git_cache.stub(:get_compiled_gem) { |source, where| nil }
      @task_git_cache.stub(:put_compiled_gem) { |source, where| nil }
    end

    it "should locate nested gemspecs" do
      @task.install_git_gem(@spec)
      gem_file = File.join(@bundler_gems_dir, "git_scope", "hello", "hello.gemspec")
      File.exists?(gem_file).should be true
      gem_file = File.join(@bundler_gems_dir, "git_scope", "gemtwo", "gemtwo.gemspec")
      File.exists?(gem_file).should be true
    end

    it "should build native extensions" do
      @task.install_git_gem(@spec)
      native_gem = File.join(@bundler_gems_dir, "git_scope", "hello")
      expect {
        require File.join(native_gem, "ext", "hello")
        ::Hello.should respond_to(:hola)
        ::Hello.hola.should == "hola"
      }.not_to raise_error
    end

    it "should check compiled gem cache" do
      @task_git_cache.should_receive(:get_compiled_gem)
      @task.install_git_gem(@spec)
    end

    it "should put compiled gem in cache if it has extensions" do
      # hello gem has extensions
      @task_git_cache.should_receive(:put_compiled_gem)
      @task.install_git_gem(@spec)
    end
  end
end