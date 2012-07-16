require 'spec_helper'

describe 'An app that uses Bundler being staged' do
  before do
    app_fixture :sinatra_gemfile
  end

  it 'is packaged with all gems excluding those in test group' do
    stage :sinatra do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3",
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
       stage(:sinatra, {:environment=>["BUNDLE_WITHOUT=development"]}) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3", "diff-lcs-1.1.3",
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
       stage(:sinatra, {:environment=>["BUNDLE_WITHOUT=development:assets"]}) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3", "diff-lcs-1.1.3",
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
       stage(:sinatra, {:environment=>["BUNDLE_WITHOUT=development: assets"]}) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3", "diff-lcs-1.1.3",
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


  describe 'that unsets BUNDLE_WITHOUT' do
    it 'is packaged with all gems' do
      stage(:sinatra, {:environment=>["BUNDLE_WITHOUT="]}) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3", "diff-lcs-1.1.3",
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

  it 'causes an error' do
    lambda {stage :sinatra}.should raise_error(RuntimeError)
  end
end

describe 'An app being staged that contains gems with github references' do
   before do
    app_fixture :sinatra_github_gemfile
  end

  it 'causes an error' do
    lambda {stage :sinatra}.should raise_error(RuntimeError)
  end
end

describe 'An app being staged that contains gems with invalid local file paths' do
  before do
    app_fixture :sinatra_gemfile_with_path
  end

  it 'causes an error' do
    lambda {stage :sinatra}.should raise_error(RuntimeError)
  end
end

describe 'An app being staged with inconsistent Gemfile and Gemfile.lock' do
  before do
    app_fixture :sinatra_inconsistent_gemfile
  end

  it 'causes an error' do
    # Some dependencies in Gemfile were removed from Gemfile.lock
    lambda {stage :sinatra}.should raise_error(RuntimeError)
  end
end

# TODO revisit this when we upgrade to Bundler 1.2.0, which adds the "ruby" method
describe 'An app being staged with Ruby version specified in Gemfile' do
  before do
    app_fixture :sinatra_ruby_version_in_gemfile
  end

  it 'causes an error' do
    lambda {stage(:sinatra)}.should raise_error(RuntimeError)
  end
end

describe 'An app being staged containing a gem designated for a specific Ruby platform' do
  before do
    app_fixture :sinatra_platforms_gemfile
  end

  it 'is packaged without the gem if ruby version does not match' do
    stage(:sinatra, {:runtime => "ruby19"}) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.9.1','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3",
            "eventmachine-0.12.10","execjs-1.4.0","json-1.5.1","multi_json-1.3.6","rack-1.2.2", "rake-0.8.7", "redis-3.0.1",
            "rubyzip-0.9.9", "sinatra-1.2.3", "thin-1.2.11", "thor-0.15.3", "tilt-1.3", "uglifier-1.2.6"]
       end
    end
  end

  it 'is packaged with the gem if ruby version matches' do
    stage(:sinatra) do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","carrot-1.2.0","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3",
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
    stage :sinatra do |staged_dir|
      Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
        Dir.glob('*').sort.should == ["bundler-1.0.10", "cf-autoconfig-0.0.3", "cf-runtime-0.0.1", "crack-0.3.1",
          "daemons-1.1.8", "eventmachine-1.0.0.rc.4", "json-1.7.3", "rack-1.4.1", "rack-protection-1.2.0",
          "sinatra-1.3.2", "thin-1.4.1", "tilt-1.3.3"]
      end
    end
  end

  describe 'that contains gems specifically designated for Windows platforms' do
    it 'is packaged with all gems excluding those in Windows platforms' do
      # Verify we don't install mysql2 gem
      stage :sinatra do |staged_dir|
        Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
          Dir.glob('*').sort.should == ["bundler-1.0.10", "cf-autoconfig-0.0.3", "cf-runtime-0.0.1", "crack-0.3.1",
            "daemons-1.1.8", "eventmachine-1.0.0.rc.4", "json-1.7.3", "rack-1.4.1", "rack-protection-1.2.0",
            "sinatra-1.3.2", "thin-1.4.1", "tilt-1.3.3"]
        end
      end
    end
  end
end
