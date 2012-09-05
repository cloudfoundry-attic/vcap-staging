require "spec_helper"
require File.expand_path("../../support/node_spec_helpers", __FILE__)

include NodeSpecHelpers

describe "A simple Node.js app being staged" do

  before do
    app_fixture :node_trivial
  end

  it "is packaged with a startup script" do
    stage node_staging_env do |staged_dir|
      start_script = File.join(staged_dir, "startup")
      start_script.should be_executable_file
    end
  end

  it "generates an auto-config script by default" do
    stage node_staging_env do |staged_dir|
      File.exists?(File.join(staged_dir, "app", "autoconfig.js")).should be_true
      start_script = File.join(staged_dir, "startup")
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS autoconfig.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
      autoconfig_script = File.join(staged_dir, "app", "autoconfig.js")
      autoconfig_body = File.read(autoconfig_script)
      autoconfig_body.should == <<-EXPECTED
process.argv[1] = require("path").resolve("app.js");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);
EXPECTED
    end
  end
end

describe "A Node.js app with auto-config options being staged" do

  describe "with auto-config disabled in cloudfoundry.json" do
    before do
      app_fixture :node_skip_autoconfig
    end

    it "does not generate an auto-config script" do
      stage node_staging_env do |staged_dir|
        File.exists?(File.join(staged_dir, "app", "autoconfig.js")).should_not be_true
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
      end
    end
  end

  describe "with cf-runtime" do
    before do
      app_fixture :node_cfruntime
    end

    it "does not generate an auto-config script" do
      stage node_staging_env do |staged_dir|
        File.exists?(File.join(staged_dir, "app", "autoconfig.js")).should_not be_true
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
      end
    end
  end
end

describe "A Node.js app being staged with a package.json" do

  describe "that defines a start script" do
    before do
      app_fixture :node_package
    end

    it "uses it for the start command" do
      stage node_staging_env do |staged_dir|
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        autoconfig_script = File.join(staged_dir, "app", "autoconfig.js")
        autoconfig_body = File.read(autoconfig_script)
        autoconfig_body.should == <<-EXPECTED
process.argv[1] = require("path").resolve("bin/app.js");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);
EXPECTED
      end
    end
  end

    describe "that defines a start command with several arguments" do
    before do
      app_fixture :node_package_arguments
    end

    it "uses it for the start command" do
      stage node_staging_env do |staged_dir|
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS autoconfig.js ./bin/app.coffee World $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED

        autoconfig_script = File.join(staged_dir, "app", "autoconfig.js")
        autoconfig_body = File.read(autoconfig_script)
        autoconfig_body.should == <<-EXPECTED
process.argv[1] = require("path").resolve("./node_modules/coffee-script/bin/coffee");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);
EXPECTED
      end
    end
  end

  describe "that defines a start script with no 'node '" do
    before do
      app_fixture :node_package_no_exec
    end
    it "uses it for the start command with executable prepended" do
      stage node_staging_env do |staged_dir|
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        autoconfig_script = File.join(staged_dir, "app", "autoconfig.js")
        autoconfig_body = File.read(autoconfig_script)
        autoconfig_body.should == <<-EXPECTED
process.argv[1] = require("path").resolve("./bin/app.js");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);
EXPECTED
      end
    end
  end

  describe "that does not parse" do
    before do
      app_fixture :node_package_bad
    end

    it "fails and lets the exception propagate" do
      proc {
        stage node_staging_env do |staged_dir|
          start_script = File.join(staged_dir, "startup")
          start_script.should be_executable_file
          autoconfig_script = File.join(staged_dir, "app", "autoconfig.js")
          autoconfig_body = File.read(autoconfig_script)
          autoconfig_body.should == <<-EXPECTED
process.argv[1] = require("path").resolve("app.js");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);
EXPECTED
        end
      }.should raise_error
    end
  end

  describe "that does not define a start script" do
    before do
      app_fixture :node_package_no_start
    end

    it "falls back onto normal detection" do
      stage node_staging_env do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        autoconfig_script = File.join(staged_dir, "app", "autoconfig.js")
        autoconfig_body = File.read(autoconfig_script)
        autoconfig_body.should == <<-EXPECTED
process.argv[1] = require("path").resolve("app.js");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);
EXPECTED
      end
    end
  end
end

describe "A Node.js app with dependencies being staged" do

  describe "with no npm-shrinkwrap.json" do
    before do
      app_fixture :node_deps_no_shrinkwrap
    end

    it "skips npm support" do
      stage node_staging_env do |staged_dir|
        pending_unless_npm_provided
        log_file = File.join(staged_dir, "logs", "staging.log")
        log_contents = File.read(log_file)
        log_contents.should match /Skipping npm support: npm-shrinkwrap.json is not provided/
      end
    end
  end

  describe "with npm-shrinkwrap.json and no node module" do
    before do
      app_fixture :node_deps_shrinkwrap
    end

    it "module will be installed with version specified in npm-shrinkwrap.json" do
      stage node_staging_env do |staged_dir|
        pending_unless_npm_provided
        package_dir = File.join(staged_dir, "app", "node_modules", "colors")
        File.exists?(package_dir).should be_true
        package_info = package_config(package_dir)
        package_info["version"].should eql("0.5.0")
      end
    end

    it "uses fetched cache" do
      cached_package = File.join(StagingPlugin.platform_config["cache"],
                                 "npm_cache/fetched/colors/0.5.0/package")
      begin
        FileUtils.mkdir_p(cached_package)
        patched_cache_file = File.join(cached_package, "cached.js")
        FileUtils.touch(patched_cache_file)
        stage node_staging_env do |staged_dir|
          pending_unless_npm_provided
          package_dir = File.join(staged_dir, "app", "node_modules", "colors")
          cached_file = File.join(package_dir, "cached.js")
          File.exists?(cached_file).should be_true
        end
      ensure
        FileUtils.rm_rf(cached_package)
      end
    end
  end

  describe "with npm-shrinkwrap.json and native dependencies" do
    before do
      app_fixture :node_deps_native
    end

    it "installs extensions" do
      stage node_staging_env do |staged_dir|
        pending_unless_npm_provided
        package_dir = File.join(staged_dir, "app", "node_modules", "bcrypt")
        built_package = File.join(package_dir, "build", "Release", "bcrypt_lib.node")
        File.exist?(built_package).should be_true
      end
    end

    it "builds user provided module" do
      # Checks that module was not fetched from registry
      stage node_staging_env do |staged_dir|
        pending_unless_npm_provided
        package_dir = File.join(staged_dir, "app", "node_modules", "bcrypt")
        patched_file = File.join(package_dir, "patched.js")
        File.exists?(patched_file).should be_true
      end
    end

    it "uses installed cache" do
      begin
        cached_package = File.join(StagingPlugin.platform_config["cache"],
                                   "npm_cache/installed/0.6.8/ba/fe/758aa3dd89f04c86ad01eede60b8d52ae740")
        FileUtils.mkdir_p(cached_package)
        patched_cache_file = File.join(cached_package, "cached.js")
        FileUtils.touch(patched_cache_file)
        stage node_staging_env do |staged_dir|
          pending_unless_npm_provided
          package_dir = File.join(staged_dir, "app", "node_modules", "bcrypt")
          cached_file = File.join(package_dir, "cached.js")
          File.exists?(cached_file).should be_true
        end
      ensure
        FileUtils.rm_rf(cached_package)
      end
    end
  end

  describe "with a shrinkwrap tree" do
    before do
      app_fixture :node_deps_tree
    end

    it "install modules according to tree" do
      stage node_staging_env do |staged_dir|
        pending_unless_npm_provided
        app_level = File.join(staged_dir, "app", "node_modules")
        colors = File.join(app_level, "colors")
        test_package_version(colors, "0.5.0")
        mime = File.join(colors, "node_modules", "mime")
        test_package_version(mime, "1.2.4")
        test_package_version(File.join(mime, "node_modules", "colors"), "0.6.0")
        test_package_version(File.join(mime, "node_modules", "async_testing"), "0.3.2")

        express = File.join(app_level, "express")
        test_package_version(express, "2.5.9")
        express_modules = File.join(express, "node_modules")
        connect = File.join(express_modules, "connect")
        test_package_version(connect, "1.8.7")
        test_package_version(File.join(connect, "node_modules", "formidable"), "1.0.9")
        test_package_version(File.join(express_modules, "mime"), "1.2.4")
        test_package_version(File.join(express_modules, "qs"), "0.4.2")
        test_package_version(File.join(express_modules, "mkdirp"), "0.3.0")
      end
    end
  end

  describe "with git dependencies in npm-shrinkwrap" do
    before do
      app_fixture :node_deps_git
    end

    it "install git modules" do
      stage node_staging_env do |staged_dir|
        pending_unless_npm_provided
        modules_dir = File.join(staged_dir, "app", "node_modules")
        test_package_version(File.join(modules_dir, "graceful-fs"), "1.1.10")
      end
    end
  end
end
