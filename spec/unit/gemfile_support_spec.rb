require 'spec_helper'

# Comprehensive unit test of Gem support
# Note: The tests with ruby18 runtime use /usr/bin/ruby
# by default.  Please make sure /usr/bin/gem is at least version 1.8.24 and
# you've done a '/usr/bin/gem install bundler -v 1.1.3'.  Alternatively you
# can set the VCAP_RUNTIME_RUBY18 env variable to the Ruby18 installed by
# dev_setup (or other Ruby, but same gem/bundler requirements apply)
describe 'An app that uses Bundler being staged' do
  before do
    app_fixture :sinatra_gemfile
  end

  it 'is packaged with all gems excluding those in test group' do
    stage sinatra_staging_env do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0","json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "redis-3.0.1",
            "rubyzip-0.9.9", "sinatra-1.2.3", "thin-1.2.11", "thor-0.15.3", "tilt-1.3", "uglifier-1.2.6"]
       end
       bundle_config = File.join(staged_dir,'app','.bundle','config')
       config_body = File.read(bundle_config)
       config_body.should == <<-EXPECTED
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
BUNDLE_WITHOUT: test
      EXPECTED
     end
  end

  describe 'that specifies one group in BUNDLE_WITHOUT' do
    it 'is packaged with gems only in groups specified by BUNDLE_WITHOUT' do
       stage(sinatra_staging_env.merge({:environment=>["BUNDLE_WITHOUT=development"]})) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3", "diff-lcs-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0", "json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "rspec-2.11.0", "rspec-core-2.11.0",
            "rspec-expectations-2.11.1", "rspec-mocks-2.11.1", "sinatra-1.2.3", "thin-1.2.11", "thor-0.15.3", "tilt-1.3", "uglifier-1.2.6"]
       end
       bundle_config = File.join(staged_dir,'app','.bundle','config')
       config_body = File.read(bundle_config)
       config_body.should == <<-EXPECTED
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
BUNDLE_WITHOUT: development
      EXPECTED
     end
    end
  end

  describe 'that specifies multiple groups in BUNDLE_WITHOUT' do
    it 'is packaged with gems only in groups specified by BUNDLE_WITHOUT' do
       stage(sinatra_staging_env.merge({:environment=>["BUNDLE_WITHOUT=development:assets"]})) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3", "diff-lcs-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0", "json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "rspec-2.11.0", "rspec-core-2.11.0",
            "rspec-expectations-2.11.1", "rspec-mocks-2.11.1", "sinatra-1.2.3", "thin-1.2.11", "tilt-1.3", "uglifier-1.2.6"]
       end
       bundle_config = File.join(staged_dir,'app','.bundle','config')
       config_body = File.read(bundle_config)
       config_body.should == <<-EXPECTED
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
BUNDLE_WITHOUT: development:assets
      EXPECTED
     end
    end
  end

  describe 'that specifies multiple groups separated by spaces in BUNDLE_WITHOUT' do
    it 'is packaged with gems only in groups specified by BUNDLE_WITHOUT' do
       stage(sinatra_staging_env.merge({:environment=>["BUNDLE_WITHOUT=development: assets"]})) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3", "diff-lcs-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0", "json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "rspec-2.11.0", "rspec-core-2.11.0",
            "rspec-expectations-2.11.1", "rspec-mocks-2.11.1", "sinatra-1.2.3", "thin-1.2.11", "tilt-1.3", "uglifier-1.2.6"]
       end
       bundle_config = File.join(staged_dir,'app','.bundle','config')
       config_body = File.read(bundle_config)
       config_body.should == <<-EXPECTED
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
BUNDLE_WITHOUT: development: assets
      EXPECTED
     end
    end
  end


  describe 'that overrides default BUNDLE_WITHOUT by setting empty value' do
    it 'is packaged with all gems' do
      stage(sinatra_staging_env.merge({:environment=>["BUNDLE_WITHOUT="]})) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3", "diff-lcs-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0", "json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "redis-3.0.1", "rspec-2.11.0", "rspec-core-2.11.0",
            "rspec-expectations-2.11.1", "rspec-mocks-2.11.1", "rubyzip-0.9.9", "sinatra-1.2.3", "thin-1.2.11", "thor-0.15.3", "tilt-1.3", "uglifier-1.2.6"]
       end
       bundle_config = File.join(staged_dir,'app','.bundle','config')
       config_body = File.read(bundle_config)
       config_body.should == <<-EXPECTED
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
      EXPECTED
     end
    end
  end
end

describe 'An app being staged that contains gems with git URLs' do
  before do
    app_fixture :sinatra_giturls_gemfile
  end

  it 'installs git gems' do
    stage(sinatra_staging_env.merge({:environment=>["BUNDLE_WITHOUT=development:assets"]})) do |staged_dir|
      rubygems_dir = File.join(staged_dir, "app", "rubygems", "ruby", "1.8")
      Dir.chdir(File.join(rubygems_dir, "gems")) do
        Dir.glob('*').sort.should == ["bundler-1.2.1", "cf-autoconfig-0.0.4", "cf-runtime-0.0.2", "daemons-1.1.8", "diff-lcs-1.1.3",
                                      "eventmachine-0.12.10", "execjs-1.4.0", "json-1.5.1", "json_pure-1.7.3", "membrane-0.0.1", "multi_json-1.3.6", "nats-0.4.24",
                                      "posix-spawn-0.3.6", "rack-1.2.2", "rake-0.8.7", "rspec-2.11.0", "rspec-core-2.11.0", "rspec-expectations-2.11.1",
                                      "rspec-mocks-2.11.1", "sinatra-1.2.3", "thin-1.3.1", "tilt-1.3", "uglifier-1.2.6", "yajl-ruby-0.8.3"]
        File.exists?(File.join(rubygems_dir, "bundler", "gems", "vcap-common-5334b662238f")).should be true

      end
    end
  end
end

describe 'An app being staged that contains gems with github references' do
   before do
    app_fixture :sinatra_github_gemfile
  end

  it 'installs git gems' do
    stage(sinatra_staging_env.merge({:environment=>["BUNDLE_WITHOUT=development:assets"]})) do |staged_dir|
      rubygems_dir = File.join(staged_dir, "app", "rubygems", "ruby", "1.8")
      Dir.chdir(File.join(rubygems_dir, "gems")) do
        Dir.glob('*').sort.should == ["bundler-1.2.1", "cf-autoconfig-0.0.4", "cf-runtime-0.0.2", "daemons-1.1.8", "diff-lcs-1.1.3",
                                      "eventmachine-0.12.10", "execjs-1.4.0", "json-1.5.1", "json_pure-1.7.3", "membrane-0.0.1", "multi_json-1.3.6", "nats-0.4.24",
                                      "posix-spawn-0.3.6", "rack-1.2.2", "rake-0.8.7", "rspec-2.11.0", "rspec-core-2.11.0", "rspec-expectations-2.11.1",
                                      "rspec-mocks-2.11.1", "sinatra-1.2.3", "thin-1.3.1", "tilt-1.3", "uglifier-1.2.6", "yajl-ruby-0.8.3"]
        File.exists?(File.join(rubygems_dir, "bundler", "gems", "vcap-common-5334b662238f")).should be true

      end
    end
  end
end

describe 'An app being staged that contains gems with valid local file paths that have been vendored' do
  before do
    app_fixture :sinatra_gemfile_with_path_vendored
  end

  it 'is packaged with the local vendored gems' do
    stage sinatra_staging_env do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["broken-0.0.1","bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2", "rack-1.4.1",
           "rack-protection-1.2.0", "sinatra-1.3.2", "tilt-1.3.3"]
       end
    end
  end
end

# TODO consider actually installing the gem from source if included in the app
describe 'An app being staged that contains gems with valid local file paths that have not been vendored' do
  before do
    app_fixture :sinatra_gemfile_with_path
  end

  it 'causes an error' do
    lambda {stage sinatra_staging_env}.should raise_error(RuntimeError)
  end
end

describe 'An app being staged with inconsistent Gemfile and Gemfile.lock' do
  before do
    app_fixture :sinatra_inconsistent_gemfile
  end

  it 'causes an error' do
    # Some dependencies in Gemfile were removed from Gemfile.lock
    lambda {stage sinatra_staging_env}.should raise_error(RuntimeError, /Error resolving Gemfile: Error parsing Gemfile: You are trying to install in deployment mode/)
  end
end

describe 'An app being staged containing a gem designated for a specific Ruby platform' do
  before do
    app_fixture :sinatra_platforms_gemfile
  end

  it 'is packaged without the gem if ruby version does not match' do
    stage(sinatra_staging_env.merge({:runtime_info => {:name => "ruby19", :version => "1.9.2p180",
     :description => "Ruby 1.9.2", :executable => "ruby"}})) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.9.1','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0","json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "redis-3.0.1",
            "rubyzip-0.9.9", "sinatra-1.2.3", "thin-1.2.11", "thor-0.15.3", "tilt-1.3", "uglifier-1.2.6"]
       end
    end
  end

  it 'is packaged with the gem if ruby version matches' do
    stage(sinatra_staging_env) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.2.1","carrot-1.2.0","cf-autoconfig-0.0.4","cf-runtime-0.0.2","daemons-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0","json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "redis-3.0.1",
            "rubyzip-0.9.9", "sinatra-1.2.3", "thin-1.2.11", "thor-0.15.3", "tilt-1.3", "uglifier-1.2.6"]
       end
    end
  end
end

describe 'An app being staged with a Gemfile.lock created on Windows' do

  before do
    app_fixture :sinatra_windows_gemfile
  end

  it 'installs the non-Windows version of the gems containing x86-mingw32 in version' do
    # Verify eventmachine version does not contain x86-mingw32
    stage sinatra_staging_env do |staged_dir|
      Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
        Dir.glob('*').sort.should == ["bundler-1.2.1", "cf-autoconfig-0.0.4", "cf-runtime-0.0.2",
          "daemons-1.1.8", "eventmachine-1.0.0.rc.4", "json-1.7.3", "rack-1.4.1", "rack-protection-1.2.0",
          "sinatra-1.3.2", "thin-1.4.1", "tilt-1.3.3"]
      end
    end
  end

  describe 'that contains gems specifically designated for Windows platforms' do
    it 'is packaged with all gems excluding those in Windows platforms' do
      # Verify we don't install mysql2 gem
      stage sinatra_staging_env do |staged_dir|
        Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
          Dir.glob('*').sort.should == ["bundler-1.2.1", "cf-autoconfig-0.0.4", "cf-runtime-0.0.2",
            "daemons-1.1.8", "eventmachine-1.0.0.rc.4", "json-1.7.3", "rack-1.4.1", "rack-protection-1.2.0",
            "sinatra-1.3.2", "thin-1.4.1", "tilt-1.3.3"]
        end
      end
    end
  end
end

describe "An app being staged with gems that depend on other gems" do
  before do
    app_fixture :sinatra_dep_gems
  end

  it "installs all gems" do
    stage sinatra_staging_env.merge({:runtime_info => {:name => "ruby19", :version => "1.9.2p180",
        :description => "Ruby 1.9.2", :executable => "ruby"}}) do |staged_dir|
      platform_specific_gem = "libv8-3.3.10.4-#{Gem::Platform.local.to_s}"
      Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.9.1','gems')) do
        Dir.glob('*').sort.should == ["bundler-1.2.1", "cf-autoconfig-0.0.4", "cf-runtime-0.0.2",
          platform_specific_gem, "rack-1.4.1", "rack-protection-1.2.0", "sinatra-1.3.3",
          "therubyracer-0.10.2", "tilt-1.3.3"]
      end
    end
  end
end

describe "An app being staged with gems that fail to install" do

  before do
    app_fixture :sinatra_broken_gem_compile
  end

  it "raises an Error" do
    lambda {stage(sinatra_staging_env)}.should raise_error(RuntimeError, /unterminated string meets end of file/)
  end
end
def sinatra_staging_env
  {:runtime_info => {
     :name => "ruby18",
     :version => "1.8.7",
     :description => "Ruby 1.8.7",
     :executable => "/usr/bin/ruby"
   },
   :framework_info => {
     :name => "sinatra",
     :runtimes => [{"ruby18"=>{"default"=>true}}, {"ruby19"=>{"default"=>false}}],
     :detection =>[{"*.rb"=>"require\\s+'sinatra'|require\\s+\"sinatra\""}, {"config.ru"=>false}, {"config/environment.rb"=>false}]
   }}
end
