require 'spec_helper'

describe "A PHP application being staged" do
  before do
    app_fixture :phpinfo
  end

  it "is packaged with a startup script" do
    stage php_staging_env do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      webapp_root = staged_dir.join('app')
      webapp_root.should be_directory
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export TMPDIR="$PWD/tmp"
env > env.log
ruby resources/generate_apache_conf $VCAP_APP_PORT $HOME $VCAP_SERVICES 512m
cd apache
bash ./start.sh > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end

  it "requests the specified amount of memory from PHP" do
    stage(php_staging_env({:memory => 256})) do |staged_dir|
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export TMPDIR="$PWD/tmp"
env > env.log
ruby resources/generate_apache_conf $VCAP_APP_PORT $HOME $VCAP_SERVICES 256m
cd apache
bash ./start.sh > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end
end

def php_staging_env(resources={})
  {:runtime_info => {
     :name => "php",
     :description => "PHP 5",
     :version => "5.3",
     :executable => "php"
   },
   :framework_info => {
     :name =>"php",
     :runtimes =>[{"php"=>{"default"=>true}}],
     :detection =>[{"*.php"=>true}]
   },
   :resources => resources}
end
