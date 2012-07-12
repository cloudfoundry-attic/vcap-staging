require "fileutils"
require "tmpdir"
require "vcap/staging/plugin/gemfile_task"

RSpec::Matchers.define :not_include do |*expected|
  match do |actual|
    RSpec::Matchers::BuiltIn::Include.new(*expected).does_not_match?(actual)
  end
end

describe GemfileTask do
  before :each do
    @base_dir = Dir.mktmpdir
    @app_dir_src = File.expand_path("../../fixtures/apps/sinatra_git/source", __FILE__)
    @app_dir = File.expand_path("source", @base_dir)
    FileUtils.cp_r(@app_dir_src, @app_dir, :preserve => true)

    # yuck, but better be gross than not testing
    @ruby_cmd = `which ruby`.strip
    @task = GemfileTask.new(@app_dir, "1.9.1", @ruby_cmd, @base_dir)
  end

  describe "#install" do
    it "should not download git gems from rubygems" do
      @task.should_receive(:install_gems).with not_include(["vcap_logging", "1.0.1"], ["eventmachine", "0.12.11.cloudfoundry.3"])
      @task.stub(:install_git_gems)
      @task.install
    end

    it "should install git gems" do
      em_install_path = File.join(@app_dir, "rubygems", "ruby", "1.9.1", "bundler", "gems", "eventmachine-2806c630d863")
      @task.stub(:install_gems)
      @task.git_path = `which git`.strip
      @task.install
      File.directory?(em_install_path).should be_true
    end
  end

  it "should find git gems" do
    @task.git_gem_specs.map {
      |h| h["name"]
    }.should == ["vcap_logging", "eventmachine"]
  end

  describe "#build_extensions" do
    before :each do
      @gem_checkout_dir = File.expand_path("native_gem", @base_dir)
      @gem_dir = File.join(@gem_checkout_dir, "hello")
      FileUtils.cp_r(File.join(@app_dir_src, "../native_gem"), @base_dir, :preserve => true)
      @native_gemspec = Gem::Specification.new("hello", "0.0.1") do |s|
        s.extensions = ["ext/extconf.rb"]
      end
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


  describe "#install_git_gems" do
    before :each do
      @gem_checkout_dir = File.expand_path("native_gem", @base_dir)
      @gem_dir = File.join(@gem_checkout_dir, "hello")
      @native_gemspec = Gem::Specification.new("hello", "0.0.1") do |s|
        s.extensions = ["ext/extconf.rb"]
      end
      @task.stub(:git_gem_specs).and_return([double(:[] => nil)])
      @task.stub(:git_checkout).and_return([@gem_dir, @native_gemspec])
    end

    it "should call #build_extensions" do
      @task.should_receive(:build_extensions).with(@gem_dir, @native_gemspec)
      @task.stub(:copy_git_gem_to_app)
      @task.install_git_gems
    end
  end

  after :each do
    FileUtils.remove_entry_secure(@base_dir)
  end
end
