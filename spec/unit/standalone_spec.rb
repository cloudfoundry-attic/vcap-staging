require 'spec_helper'

describe "A Standalone app being staged" do

   describe "when bundled" do
    before do
      app_fixture :standalone_gemfile
    end

    describe "and using Ruby 1.8" do
      it "is packaged with a startup script" do
        stage({:framework_info => {:name => "standalone"},:meta=>{:command=> "ruby app.rb"}, :runtime_info=> ruby18_runtime}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:$PATH"
export RUBYOPT="-I$PWD/ruby -I$PWD/app/rubygems/ruby/1.8/gems/cf-autoconfig-#{AUTO_CONFIG_GEM_VERSION}/lib -rcfautoconfig -rstdsync"
export TMPDIR="$PWD/tmp"
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby app.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
        EXPECTED
        end
      end
      it "installs gems" do
        stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "ruby app.rb"}, :runtime_info=> ruby18_runtime}) do |staged_dir|
          gemdir = File.join(staged_dir,'app','rubygems','ruby','1.8')
          Dir.entries(gemdir).should_not == []
        end
      end
      it "installs autoconfig gem" do
       stage ({:framework_info => {:name => "standalone"}, :meta=>{:command=> "ruby app.rb"}, :runtime_info=> ruby18_runtime}) do |staged_dir|
         gemfile = File.join(staged_dir,'app','Gemfile')
         gemfile_body = File.read(gemfile)
         gemfile_body.should == <<-EXPECTED
source "http://rubygems.org"
gem "sinatra"
gem "thin"
gem "json"

gem "cf-autoconfig"
         EXPECTED
       end
     end
    end
    describe "and using Ruby 1.9" do
      it "is packaged with a startup script" do
        stage({:framework_info => {:name => "standalone"},:meta=>{:command=> "ruby app.rb"}, :runtime_info=> ruby19_runtime}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.9.1"
export GEM_PATH="$PWD/app/rubygems/ruby/1.9.1"
export PATH="$PWD/app/rubygems/ruby/1.9.1/bin:$PATH"
export RUBYOPT="-I$PWD/ruby  -rcfautoconfig -rstdsync"
export TMPDIR="$PWD/tmp"
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby app.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
        EXPECTED
        end
      end
      it "installs gems" do
        stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "ruby app.rb"}, :runtime_info=> ruby19_runtime}) do |staged_dir|
          gemdir = File.join(staged_dir,'app','rubygems','ruby','1.9.1')
          Dir.entries(gemdir).should_not == []
        end
      end
      it "installs autoconfig gem" do
       stage ({:framework_info => {:name => "standalone"}, :meta=>{:command=> "ruby app.rb"}, :runtime_info=> ruby19_runtime}) do |staged_dir|
         gemfile = File.join(staged_dir,'app','Gemfile')
         gemfile_body = File.read(gemfile)
         gemfile_body.should == <<-EXPECTED
source "http://rubygems.org"
gem "sinatra"
gem "thin"
gem "json"

gem "cf-autoconfig"
         EXPECTED
       end
     end
    end
  end

  describe "when using Ruby and not bundled" do
    before do
      app_fixture :standalone_simple_ruby
    end

    describe "and using Ruby 1.8" do
      it "is packaged with a startup script" do
        stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "ruby hello.rb"}, :runtime_info=> ruby18_runtime}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
export TMPDIR="$PWD/tmp"
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby hello.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
      end
    end
    describe "and using Ruby 1.9" do
      it "is packaged with a startup script" do
        stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "ruby hello.rb"}, :runtime_info=> ruby19_runtime}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
export TMPDIR="$PWD/tmp"
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby hello.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
      end
    end
  end

  describe "with Java runtime" do
    before do
      app_fixture :standalone_java
    end
    it "is packaged with a startup script" do
      stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "java $JAVA_OPTS HelloWorld"}, :runtime_info=> {:name => "java"}, :resources=>{:memory=>512}}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export JAVA_OPTS="$JAVA_OPTS -Xms512m -Xmx512m -Djava.io.tmpdir=$PWD/tmp"
export TMPDIR="$PWD/tmp"
cd app
java $JAVA_OPTS HelloWorld > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
    end
    it "creates a temp dir" do
      stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "java $JAVA_OPTS HelloWorld"}, :runtime_info=> {:name => "java"}, :resources=>{:memory=>512}}) do |staged_dir|
          tmp_dir = File.join(staged_dir, "tmp")
          File.exists?(tmp_dir).should == true
        end
    end
  end

  describe "with Python runtime" do
    before do
      app_fixture :standalone_python
    end
    it "is packaged with a startup script" do
      stage({:framework_info => {:name => "standalone"}, :meta=>{:command=> "python HelloWorld.py"}, :runtime_info=> {:name => "python2"}, :resources=>{:memory=>512}}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export PYTHONUNBUFFERED="true"
export TMPDIR="$PWD/tmp"
cd app
python HelloWorld.py > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
    end
  end
end
def ruby18_runtime
  {:name => "ruby18",
   :version => "1.8.7",
   :executable => "/usr/bin/ruby"}
end
def ruby19_runtime
  {:name => "ruby19",
   :version => "1.9.2",
   :executable => "ruby"}
end
