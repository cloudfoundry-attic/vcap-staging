require "rubygems/package_task"
require "rspec/core/rake_task"
require "ci/reporter/rake/rspec"
require "tmpdir"

Gem::PackageTask.new(Gem::Specification.load("vcap_staging.gemspec")).define

desc "build gem"
task :build => :gem

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rspec_opts = ["--color", "--format nested"]
end

task :default => [:spec]

desc "Run tests for CI"
task "ci:spec" => ["ci:setup:rspec", :spec]

desc "Update node cf-autoconfig module"
task :update_node_cf_autoconfig_module do
  git_url = "git://github.com/cloudfoundry/vcap-node.git"
  Dir.mktmpdir do |tmp_dir|
    Dir.chdir(tmp_dir) do
      sh("git clone --no-hardlinks #{git_url}")
      module_dir = File.join(tmp_dir, "vcap-node", "cf-autoconfig")
      Dir.chdir(module_dir) do
        revision =  ENV["REVISION"] || "latest"
        unless revision == "latest"
          sh("git reset --hard #{revision}")
        end
        # Npm install will generate current system specific files, so we don't run it
        # Overwrite module lib files
        dest = File.expand_path("../lib/vcap/staging/plugin/node/resources/node_modules/cf-autoconfig", __FILE__)
        FileUtils.cp_r(File.join(module_dir, "lib"), dest)
      end
    end
  end
end
