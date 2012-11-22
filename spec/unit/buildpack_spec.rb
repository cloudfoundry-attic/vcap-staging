require 'spec_helper'

describe "Buildpack Plugin" do
  context "with a rails 3 app" do
    before do
      app_fixture :rails3_no_assets
    end

    it "copies app to the destination" do
      stage buildpack_staging_env do |staged_dir|
        File.should be_file("#{staged_dir}/app/app/controllers/application_controller.rb")
      end
    end

    it "creates vendor/ruby directory" do
      stage buildpack_staging_env do |staged_dir|
        File.should be_directory("#{staged_dir}/app/vendor/ruby-1.9.2")
      end
    end

    it "captures output to the staging log" do
      stage buildpack_staging_env do |staged_dir|
        staging_log = File.join(staged_dir, 'logs', 'staging.log')
        staging_log_body = File.read(staging_log)
        staging_log_body.should include("-----> Writing config/database.yml to read from DATABASE_URL")
      end
    end

    it "puts the environment variables provided by 'release' into the startup script" do
      stage buildpack_staging_env([postgres_service]) do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
        script_body = File.read(start_script)
        script_body.should include('export HOME="$PWD/app"')
        script_body.should include('export GEM_PATH="${GEM_PATH:-vendor/bundle/ruby/1.9.1}"')
        script_body.should include('export RAILS_ENV')
        script_body.should include('export PORT="$VCAP_APP_PORT"')
        script_body.should include('export DATABASE_URL="postgres://testuser:test@myhost:345/mydb"')
      end
    end

    it "sources everything in profile.d/*.sh after the config vars" do
      stage buildpack_staging_env do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should  include(<<-EXPECTED)
if [ -d app/.profile.d ]; then
  for i in app/.profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
        EXPECTED
      end
    end

    it "is packaged with the start command" do
      stage buildpack_staging_env do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should include("bundle exec thin start -R config.ru -e $RAILS_ENV -p $PORT > ../logs/stdout.log 2> ../logs/stderr.log &")
      end
    end
  end

  def postgres_service
    {:label=>"postgresql-9.0",
      :credentials=> {
          :hostname=>"myhost",
          :user=>"testuser",
          :port=>345,
          :password=>"test",
          :name=>"mydb"}
    }
  end

  def buildpack_staging_env(services=[])
    {:runtime_info => {
        :name => "ruby18",
        :version => "1.8.7",
        :description => "Ruby 1.8.7",
        :executable => "/usr/bin/ruby",
        :bundler => "/usr/bin/bundle",
        :environment => {"bundle_gemfile"=>nil}
    },
     :framework_info => {
         :name => "buildpack",
         :runtimes => [{"ruby18"=>{"default"=>true}}, {"ruby19"=>{"default"=>false}}]
     },
    :services => services
    }
  end
end
