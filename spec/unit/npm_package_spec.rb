require "spec_helper"
require "vcap/staging/plugin/node/npm_support/npm_package"
require "vcap/staging/plugin/node/npm_support/npm_helper"
require File.expand_path("../../support/node_spec_helpers", __FILE__)

describe NpmPackage do
  include NodeSpecHelpers

  before :each do
    @logger = double("Logger").as_null_object
    @cache = double("Cache").as_null_object
    @git_cache = double("GitCache").as_null_object
    @runtime_info = node_staging_env[:runtime_info]
    @working_dir = Dir.mktmpdir
  end

  after :each do
    FileUtils.rm_rf(@working_dir) if @working_dir
  end

  it "should verify if package has native extensions" do
    # has_native_extensions?
    app = app_fixture_base_directory.join("node_deps_native", "source")
    package_path = File.join(app, "node_modules", "bcrypt")
    package = NpmPackage.new("bcrypt", {"version" => "0.4.0"}, package_path, nil, nil,
                             @runtime_info, @logger, @cache, @git_cache)
    package.has_native_extensions?(package_path).should be true

    app = app_fixture_base_directory.join("node_deps_installed", "source")
    package_path = File.join(app, "node_modules", "colors")
    package = NpmPackage.new("colors", {"version" => "0.6.0-1"}, package_path, nil, nil,
                             @runtime_info, @logger, @cache, @git_cache)
    package.has_native_extensions?(package_path).should_not be true
  end

  it "should return consistent hash" do
    # clean_package_hash
    app = app_fixture_base_directory.join("node_deps_native", "source")
    node_module = File.join(app, "node_modules", "bcrypt")
    FileUtils.cp_r(node_module, @working_dir)
    package_path = File.join(@working_dir, "bcrypt")
    package = NpmPackage.new("bcrypt", {"version" => "0.4.0"}, package_path, nil, nil,
                             @runtime_info, @logger, @cache, @git_cache)

    hash = package.clean_package_hash(package_path)
    package.build(package_path)
    installed_hash = package.clean_package_hash(package_path)

    installed_hash.should == hash
  end

  it "copies to destination directory" do
    # copy_to_dst
    app_source = app_fixture_base_directory.join("node_deps_native", "source")
    app_test = File.join(@working_dir, "app")
    FileUtils.copy_entry(app_source, app_test, true)
    package_path = File.join(app_test, "node_modules", "bcrypt")

    module_test = File.join(@working_dir, "module")
    FileUtils.mkdir_p(module_test)

    package = NpmPackage.new("bcrypt", {"version" => "0.4.0"}, package_path, nil, nil,
                             @runtime_info, @logger, @cache, @git_cache)

    FileUtils.touch(File.join(module_test, "copied"))

    package.copy_to_dst(module_test)
    File.exists?(File.join(package_path, "copied")).should be true
  end

  it "detects if git source" do
    # url_provided?
    package = NpmPackage.new("bcrypt", {"version" => "0.4.0"}, @working_dir, nil, nil,
                             @runtime_info, @logger, @cache, @git_cache)
    package.url_provided?.should_not be

    package = NpmPackage.new("bcrypt", {"version" => "git://github.com/ncb000gt/node.bcrypt.js.git"},
                             @working_dir, nil, nil, @runtime_info, @logger, @cache, @git_cache)
    package.url_provided?.should be

    package = NpmPackage.new("bcrypt", {"version" => "0.4.0",
                                        "from" => "git://github.com/ncb000gt/node.bcrypt.js.git"},
                             @working_dir, nil, nil, @runtime_info, @logger, @cache, @git_cache)
    package.url_provided?.should be
  end

  it "outputs error message if package can't be found" do
    error_message = "Package is not found in npm registry cf-runtime@0.0.0"
    @logger.should_receive(:error).with(/#{error_message}/)
    package = NpmPackage.new("cf-runtime", {"version" => "0.0.0"},
                             @working_dir, nil, nil, @runtime_info, @logger, @cache, @git_cache)
    package.get_registry_data
  end

  it "outputs error message if connection timeout" do
    Net::HTTP.should_receive(:get_response).and_raise(Timeout::Error)

    error_message = "Timeout error requesting npm registry"
    @logger.should_receive(:error).with(/#{error_message}/)
    package = NpmPackage.new("bcrypt", {"version" => "0.5.0"},
                             @working_dir, nil, nil, @runtime_info, @logger, @cache, @git_cache)
    package.get_registry_data
  end

  it "outputs error message if node and npm versions are not satisfied" do
    pending_unless_npm_provided
    error_message = "Node version requirement >=0.8 is not compatible" +
        " with the current node version 0.6.8"
    @logger.should_receive(:error).with(/#{error_message}/)
    package = NpmPackage.new("test", {"version" => "0.5.0"},
                             @working_dir, nil, nil, @runtime_info, @logger, @cache, @git_cache)
    package.stub(:package_config) do |path|
      { "engines" => { "node" => ">=0.8" } }
    end
    package.engine_version_satisfied?(@working_dir)
  end

  it "outputs error message if installation failed" do
    pending_unless_npm_provided
    app = app_fixture_base_directory.join("node_deps_native", "source")
    node_module = File.join(app, "node_modules", "bcrypt")
    FileUtils.cp_r(node_module, @working_dir)
    package_path = File.join(@working_dir, "bcrypt")

    error_message = "Failed building package: bcrypt@0.4.0"
    @logger.should_receive(:error).with(/#{error_message}/)

    error_message = "Error: ENOENT, no such file or directory .*package.json"
    @logger.should_receive(:error).with(/#{error_message}/)

    package = NpmPackage.new("bcrypt", {"version" => "0.4.0"},
                             package_path, nil, nil, @runtime_info, @logger, @cache, @git_cache)

    # npm installation fails without package.json
    FileUtils.rm(File.join(package_path, "package.json"))

    package.build(package_path)
  end
end