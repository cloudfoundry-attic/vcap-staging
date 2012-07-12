require "fileutils"
require "tmpdir"
require "vcap/staging/plugin/gemfile_task"

describe GemfileTask do
  before :each do
    @base_dir = Dir.mktmpdir
    @app_dir_src = File.expand_path("../../fixtures/apps/sinatra_git/source", __FILE__)
    @app_dir = File.expand_path("source", @base_dir)
    FileUtils.cp_r(@app_dir_src, @app_dir, :preserve => true)

    # yuck, but better be gross than not testing
    ruby_cmd = `which ruby`.strip
    git_cmd = `which git`.strip
    @task = GemfileTask.new(@app_dir, "1.9.1", ruby_cmd, git_cmd, @base_dir)
    # The tests will still work without short-circuiting this, but the
    # turnaround time will become prohibitively long, e.g.  EventMachine
    # takes 10+ seconds just to compile
    @task.stub(:build_extensions)
  end

  after :each do
    FileUtils.remove_entry_secure(@base_dir)
  end

  describe "#install" do
    it "should not download git gems from rubygems" do
      @task.stub(:install_rubygems_gem) do |name, version|
        ["vcap_logging", "eventmachine"].should_not include name
      end
      @task.stub(:install_git_gem)
      @task.install
    end

    it "should find git gems" do
      @task.locked_dependencies.specs.select { |s|
        s.source.is_a? Bundler::Source::Git
      }.map { |s|
        s.name
      }.sort.should == ["eventmachine", "vcap_logging"]
    end

    it "should install git gems" do
      seen = []
      @task.stub(:install_rubygems_gem)
      @task.stub(:install_git_gem) do |name, version, source|
        seen << [name, version]
      end
      @task.install
      seen.sort.should == [["eventmachine", "0.12.11.cloudfoundry.3"], ["vcap_logging", "1.0.1"]]
    end

    it "should install git gems in the same location as Bundler" do
      em_install_path = File.join(@app_dir, "rubygems", "ruby", "1.9.1", "bundler", "gems", "eventmachine-2806c630d863")
      @task.stub(:install_rubygems_gem)
      @task.stub(:build_extensions)
      @task.install
      File.directory?(em_install_path).should be_true
    end

    it "should find gems nested in the repo" do
      logging_gem_install_path = File.join(@app_dir, "rubygems", "ruby", "1.9.1", "bundler", "gems", "common-e36886a189b8")
      @task.stub(:install_rubygems_gem)
      @task.stub(:build_extensions)
      @task.install
      File.directory?(logging_gem_install_path).should be_true
      Dir.glob(File.join(logging_gem_install_path, "**/vcap_logging.gemspec")).should_not be_empty
    end
  end

  describe "#git_checkout" do
    it "should check out the right revision" do
      Dir.mktmpdir do |dir|
        @task.git_checkout(
          dir,
          "git://github.com/cloudfoundry/common.git",
          "e36886a189b82f880a5aa3e9169712d5d9048a88",
          "vcap_logging",
        )
        File.read(File.join(dir, ".git", "HEAD")).should start_with("e36886a1")
      end
    end
  end

  describe "#build_extensions" do
    before :each do
      @gem_checkout_dir = File.expand_path("native_gem", @base_dir)
      @gem_dir = File.join(@gem_checkout_dir, "hello")
      FileUtils.cp_r(File.join(@app_dir_src, "../native_gem"), @base_dir, :preserve => true)
      @native_gemspec = Gem::Specification.new("hello", "0.0.1") do |s|
        s.extensions = ["ext/extconf.rb"]
      end
      @task.unstub(:build_extensions)
    end

    it "should build native extensions" do
      @task.build_extensions(@gem_dir, @native_gemspec)
      expect {
        require File.join(@gem_dir, "lib/ext")
        ::Hello.should respond_to(:hola)
        ::Hello.hola.should == "hola"
      }.not_to raise_error
    end
  end

  describe "#install_git_gem" do
    before :each do
      @gem_checkout_dir = File.expand_path("native_gem", @base_dir)
      @gem_dir = File.join(@gem_checkout_dir, "hello")
      FileUtils.cp_r(File.join(@app_dir_src, "../native_gem"), @base_dir, :preserve => true)
      @native_gemspec = Gem::Specification.new("hello", "0.0.1") do |s|
        s.extensions = ["ext/extconf.rb"]
      end
      @task.stub(:git_checkout).and_return([@gem_dir, @native_gemspec])
      @task.unstub(:build_extensions)
    end

    it "should call #build_extensions" do
      @task.should_receive(:build_extensions).with(@gem_dir, @native_gemspec)
      @task.stub(:copy_git_gem_to_app)
      @task.install_git_gem("hello", "0.0.1", double.as_null_object)
    end

    it "should build native extensions" do
      @task.stub(:copy_git_gem_to_app)
      @task.install_git_gem("hello", "0.0.1", double.as_null_object)
      expect {
        require File.join(@gem_dir, "lib/ext")
        ::Hello.should respond_to(:hola)
        ::Hello.hola.should == "hola"
      }.not_to raise_error
    end
  end
end
