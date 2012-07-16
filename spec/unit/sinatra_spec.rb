require 'spec_helper'

describe "A simple Sinatra app being staged" do
  before do
    app_fixture :sinatra_trivial
  end

  it "is packaged with a startup script" do
    stage :sinatra do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
#{executable} app.rb $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end

  it "contains a log indicating disabled autoconfig" do
    stage :sinatra do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      staging_log = File.join(staged_dir, 'logs','staging.log')
      log_body = File.read(staging_log)
      log_body.should =~ /Auto-reconfiguration disabled because app does not use Bundler./
    end
  end

  describe "when bundled" do
    before do
      app_fixture :sinatra_gemfile
    end

    it "is packaged with a startup script" do
      stage :sinatra do |staged_dir|
        executable = '%VCAP_LOCAL_RUNTIME%'
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:$PATH"
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-I$PWD/ruby -I$PWD/app/rubygems/ruby/1.8/gems/cf-autoconfig-#{AUTO_CONFIG_GEM_VERSION}/lib -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} -rcfautoconfig ./app.rb $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
      end
    end

   it "installs autoconfig gem" do
     stage :sinatra do |staged_dir|
       gemfile = File.join(staged_dir,'app','Gemfile')
       gemfile_body = File.read(gemfile)
       gemfile_body.should == <<-EXPECTED
source "http://rubygems.org"
gem "rake"
gem "sinatra"
gem "thin"
gem "json"
group :test do
  gem "rspec"
end

gem "cf-autoconfig"
     EXPECTED
     end
   end

   it "installs gems" do
     stage :sinatra do |staged_dir|
       Dir.chdir(File.join(staged_dir,'app', 'rubygems', 'ruby', '1.8','gems')) do
         Dir.glob('*').sort.should == ["bundler-1.0.10","cf-autoconfig-0.0.3","cf-runtime-0.0.1","crack-0.3.1","daemons-1.1.3",
            "eventmachine-0.12.10","json-1.5.1","rack-1.2.2", "rake-0.8.7","sinatra-1.2.3", "thin-1.2.11", "tilt-1.3"]
       end
     end
   end

   it "writes bundle config" do
     stage :sinatra do |staged_dir|
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
  end
end
