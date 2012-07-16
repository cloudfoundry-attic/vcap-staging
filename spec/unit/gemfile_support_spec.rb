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

  describe 'that contains gems with local file paths' do

  end

  describe 'that contains gems with git URLs' do
    # TODO
  end

  describe 'that contains gems with github references' do
    # TODO - example gem "rails", :github => "rails/rails"
  end
end

describe 'An app being staged with inconsistent Gemfile and Gemfile.lock' do
  it 'causes an error' do
  #missing or added deps
  end
end

describe 'An app being staged with incompatible Ruby version in Gemfile' do
  # TODO
end

describe 'An app being staged that was locally installed with gems matching platform, but does not match on cf' do
    # Gem in ruby_19 platform.  Gemfile.lock was created with 1.9, but app is 1.8 on cf
    it 'is packaged only with gems matching the current platform' do
    end
  end

describe 'An app being staged that was locally installed with gems not matching platform, but does match on cf' do
    # Gem in ruby_18 platform.  Gemfile.lock was created with 1.9, but app is 1.8 on cf
  end

describe 'An app being staged that was locally installed with gems not matching platform, and does not match on cf' do
  # Gem in ruby_19 platform.  Gemfile.lock was created with 1.8 and app is 1.8 on cf
end

describe 'An app being staged with a Gemfile.lock created and gems packaged on Windows' do

  before do
    app_fixture :rails3_windows_gemfile
  end

  it 'does something' do
    stage :rails3 do |staged_dir|
      Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         #puts Dir.glob('*')
      end
    end
  end

  describe 'that contains gems specifically designated for Windows platforms' do
    it 'is packaged with all gems excluding those in Windows platforms' do
    end
  end
end

describe 'An app being staged with a Gemfile.lock created on Windows without gems packaged' do
  # TODO tests above without bundle package
end
