require "spec_helper"
require "vcap/staging/plugin/gemspec_builder"

describe "GemspecBuilder" do

  before :each do
    @ruby_cmd = ENV["VCAP_RUNTIME_RUBY19"] || "ruby"
    @logger = mock("Logger")
    git_gems_dir = app_fixture_base_directory.join("sinatra_git", "test_gem")
    @working_dir = Dir.mktmpdir
    FileUtils.copy_entry(git_gems_dir, @working_dir, true)
  end

  after :each do
    FileUtils.rm_rf(@working_dir)
  end

  it "should require build if gemspec has extensions" do
    gemspec_path = File.join(@working_dir, "hello", "hello.gemspec")
    gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
    gemspec.requires_build?.should be true
  end

  it "should not require build if gemspec has no extensions" do
    gemspec_path = File.join(@working_dir, "gemtwo", "gemtwo.gemspec")
    gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
    gemspec.requires_build?.should_not be true
  end

  it "should log an error if problem determining gemspec extensions" do
    # Pass an invalid gemspec name
    gemspec = GemspecBuilder.new("foo", @ruby_cmd, @logger)
    @logger.should_receive(:error).with("Failed checking for gem extensions from foo: -e:1:in `<main>': undefined method `extensions' for nil:NilClass (NoMethodError)")
    gemspec.requires_build?.should_not be true
  end

  it "should update gemspec" do
    gemspec_path = File.join(@working_dir, "gemtwo", "gemtwo.gemspec")
    gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
    gemspec.update
    gemspec_data = File.read(gemspec_path)
    gemspec_data.should_not match /Gemtwo::VERSION/
    gemspec_data.should match /s\.version = "0\.0\.1"/
  end

  it "should update gemspec from path" do
    gemspec_path = File.join(@working_dir, "gemtwo", "gemtwo.gemspec")
    gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
    new_gemspec_path = File.join(@working_dir, "hello", "hello.gemspec")
    gemspec.update_from_path(new_gemspec_path)
    gemspec_data = File.read(gemspec_path)
    gemspec_data.should_not match /s\.name = "gemtwo"/
    gemspec_data.should match /s\.name = "hello"/
  end

  it "should log an error if problem updating gemspec from path" do
    gemspec_path = File.join(@working_dir, "gemtwo", "gemtwo.gemspec")
    gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
    new_gemspec_path = File.join("foo", "hello", "hello.gemspec")
    @logger.should_receive(:error).with("Failed updating gemtwo.gemspec.  Unable to copy gemspec to new path.")
    gemspec.update_from_path(new_gemspec_path)
  end

  it "should log an error if problem updating gemspec" do
    # Pass an invalid gemspec name
    gemspec = GemspecBuilder.new("foo", @ruby_cmd, @logger)
    @logger.should_receive(:error).with("Failed updating foo: -e:1:in `<main>': undefined method `to_ruby_for_cache' for nil:NilClass (NoMethodError)")
    gemspec.update
  end

  it "should build gem from gemspec" do
    gemspec_path = File.join(@working_dir, "gemtwo", "gemtwo.gemspec")
    gemspec = GemspecBuilder.new(gemspec_path, @ruby_cmd, @logger)
    built_gem = gemspec.build
    File.exists?(built_gem).should be true
    built_gem.should == File.join(@working_dir, "gemtwo", "gemtwo-0.0.1.gem")
  end

  it "should raise an error if unable to build gem from gemspec" do
    gemspec = GemspecBuilder.new("foo", @ruby_cmd, @logger)
    @logger.should_receive(:error).with("Failed building gem foo: ERROR:  Gemspec file not found: foo")
    lambda {gemspec.build}.should raise_error "Failed building gem foo: ERROR:  Gemspec file not found: foo"
  end
end
