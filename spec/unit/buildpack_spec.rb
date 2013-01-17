require 'spec_helper'
require 'vcap/staging/plugin/buildpack/plugin'
require 'rr'

describe "Buildpack Plugin" do
  let(:fake_buildpacks_dir) { File.expand_path("../../fixtures/fake_buildpacks", __FILE__) }
  let(:buildpacks_path_with_start_cmd) { "#{fake_buildpacks_dir}/with_start_cmd" }
  let(:buildpacks_path_without_start_cmd) { "#{fake_buildpacks_dir}/without_start_cmd" }
  let(:buildpacks_path_with_no_match) { "#{fake_buildpacks_dir}/with_no_match" }

  let(:buildpacks_path) { buildpacks_path_with_start_cmd }
  let(:app_with_procfile) { :node_deps_native }
  let(:app_without_procfile) { :node_without_procfile }

  before do
    any_instance_of(BuildpackPlugin) do |plugin|
      stub(plugin).buildpacks_path { Pathname.new(buildpacks_path) }
    end
  end

  shared_examples_for "successful buildpack compilation" do
    it "copies the app directory to the correct destination" do
      stage staging_env do |staged_dir|
        File.should be_file("#{staged_dir}/app.js")
      end
    end

    it "captures output to the staging log" do
      stage staging_env do |staged_dir|
        staging_log = File.join(staged_dir, 'logs', 'staging.log')
        staging_log_body = File.read(staging_log)
        staging_log_body.should include("-----> Some compilation output")
      end
    end

    it "puts the environment variables provided by 'release' into the startup script" do
      stage staging_env do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
        script_body = File.read(start_script)
        script_body.should include('export FROM_BUILD_PACK="${FROM_BUILD_PACK:-yes}"')
      end
    end

    it "stores everything in profile" do
      stage staging_env do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
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
    end
  end

  let(:staging_env) { buildpack_staging_env }

  context "when a start command is passed" do
    let(:staging_env) { buildpack_staging_env.merge({:meta => {:command => "node app.js --from-manifest=true"}}) }

    before { app_fixture app_without_procfile }

    it_behaves_like "successful buildpack compilation"

    it "uses the passed start command" do
      stage staging_env do |staged_dir|
        packages_with_start_script(staged_dir, "node app.js --from-manifest=true")
      end
    end
  end

  context "when the application has a procfile" do
    before { app_fixture app_with_procfile }

    it_behaves_like "successful buildpack compilation"

    it "uses the start command specified by the 'web' key in the procfile" do
      stage staging_env do |staged_dir|
        packages_with_start_script(staged_dir, "node app.js --from-procfile=true")
      end
    end

    it "raise a good error if the procfile is not a hash" do
      app_fixture :node_invalid_procfile
      expect {
        stage staging_env
      }.to raise_error("Invalid Procfile format.  Please ensure it is a valid YAML hash")
    end
  end

  context "when no start command is passed and the application does not have a procfile" do
    before { app_fixture app_without_procfile }

    context "when the buildpack provides a default start command" do
      it_behaves_like "successful buildpack compilation"

      it "uses the default start command" do
        stage staging_env do |staged_dir|
          packages_with_start_script(staged_dir, "node app.js --from-buildpack=true")
        end
      end
    end

    context "when the buildpack does not provide a default start command" do
      let(:buildpacks_path) { buildpacks_path_without_start_cmd }

      it "raises an error " do
        expect {
          stage staging_env
        }.to raise_error("Please specify a web start command in your manifest.yml or Procfile")
      end
    end

    context "when staging an app which does not match any build packs" do
      let(:buildpacks_path) { buildpacks_path_with_no_match }

      it "raises an error" do
        expect {
          stage staging_env
        }.to raise_error("Unable to detect a supported application type")
      end
    end
  end

  def packages_with_start_script(staged_dir, start_command)
    start_script = File.join(staged_dir, 'startup')
    start_script.should be_executable_file
    script_body = File.read(start_script)
    script_body.should include("#{start_command} > $DROPLET_BASE_DIR/logs/stdout.log 2> $DROPLET_BASE_DIR/logs/stderr.log &")
  end

  def buildpack_staging_env(services=[])
    {:runtime_info => {
        :name => "ruby18",
        :version => "1.8.7",
        :description => "Ruby 1.8.7",
        :executable => "/usr/bin/ruby",
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