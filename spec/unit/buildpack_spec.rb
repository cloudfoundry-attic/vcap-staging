require 'spec_helper'

describe "Buildpack Plugin" do
  it "stages a rails 3 app" do
    app_fixture :rails3_with_ruby_version

    stage buildpack_staging_env do |staged_dir|
      copies_app_to_destination?(staged_dir)
      creates_vendor_ruby_dir(staged_dir)
      captures_output_to_the_staging_log(staged_dir)
      stores_everything_in_profile(staged_dir)
      packages_with_start_script(staged_dir)
    end
  end

  def copies_app_to_destination?(staged_dir)
    File.should be_file("#{staged_dir}/app/controllers/application_controller.rb")
  end

  def captures_output_to_the_staging_log(staged_dir)
    staging_log = File.join(staged_dir, 'logs', 'staging.log')
    staging_log_body = File.read(staging_log)
    staging_log_body.should include("-----> Writing config/database.yml to read from DATABASE_URL")
  end

  def creates_vendor_ruby_dir(staged_dir)
    File.should be_directory("#{staged_dir}/vendor/ruby-1.9.2")
  end

  def stores_everything_in_profile(staged_dir)
    start_script = File.join(staged_dir, '.cloudfoundry','startup')
    start_script.should be_executable_file
    script_body = File.read(start_script)
    script_body.should include(<<-EXPECTED)
if [ -d .profile.d ]; then
  for i in .profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
    EXPECTED
  end

  def packages_with_start_script(staged_dir)
    start_script = File.join(staged_dir, '.cloudfoundry', 'startup')
    start_script.should be_executable_file
    script_body = File.read(start_script)
    script_body.should include("bundle exec thin start -R config.ru -e $RAILS_ENV -p $PORT > $DROPLET_BASE_DIR/logs/stdout.log 2> $DROPLET_BASE_DIR/logs/stderr.log &")
  end

  it "puts the environment variables provided by 'release' into the startup script" do
    app_fixture :rails3_with_ruby_version

    stage buildpack_staging_env([postgres_service]) do |staged_dir|
      start_script = File.join(staged_dir, '.cloudfoundry', 'startup')
      script_body = File.read(start_script)
      script_body.should include('export GEM_PATH="${GEM_PATH:-vendor/bundle/ruby/1.9.1}"')
      script_body.should include('export RAILS_ENV')
      script_body.should include('export PORT="$VCAP_APP_PORT"')
      script_body.should include('export DATABASE_URL="postgres://testuser:test@myhost:345/mydb"')
      script_body.should include('export TMPDIR="$PWD/.cloudfoundry/tmp"')
    end
  end

  context "with a node app" do
    before do
      app_fixture :node_deps_native
    end

    it "gives it a start command" do
      stage buildpack_staging_env do |staged_dir|
        start_script = File.join(staged_dir, '.cloudfoundry', 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should include("node app.js > $DROPLET_BASE_DIR/logs/stdout.log 2> $DROPLET_BASE_DIR/logs/stderr.log &")
      end
    end
  end

  context "when staging an app which does not match any build packs" do
    it "raises an error" do
      app_fixture :phpinfo

      expect { stage buildpack_staging_env }.to raise_error "Unable to detect a supported application type"
    end
  end

  describe "Procfile support" do
    it "uses the 'web' process start command" do
      app_fixture :node_deps_native
      stage buildpack_staging_env do |staged_dir|
        start_script = File.join(staged_dir, '.cloudfoundry', 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should include("node app.js > $DROPLET_BASE_DIR/logs/stdout.log 2> $DROPLET_BASE_DIR/logs/stderr.log &")
      end
    end

    it "raises an error if the buildpack does not provide a default start command and there is no procfile" do
      app_fixture :node_without_procfile
      expect { stage buildpack_staging_env }.to raise_error("Please specify a web start command using a Procfile")
    end

    it "raise a good error if the procfile is not a hash" do
      app_fixture :node_invalid_procfile
      expect { stage buildpack_staging_env }.to raise_error("Invalid Procfile format.  Please ensure it is a valid YAML hash")
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