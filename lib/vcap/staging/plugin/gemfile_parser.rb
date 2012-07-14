require 'rubygems'
require 'bundler'
require 'yaml'

def bundle_definition
  @bundle ||= \
    begin
      bundle_definition = Bundler::Definition.build("Gemfile","Gemfile.lock",nil)
      bundle_definition.ensure_equivalent_gemfile_and_lockfile
      bundle_definition
    rescue => e
      puts "Error parsing Gemfile: #{e}"
      exit 1
    end
end

def specs
  @specs ||= \
  begin
    locked_specs = bundle_definition.resolve
    dependency_specs = locked_specs.find_all{|item| dependencies.map {|dep| dep.name}.include? item.name }
    specs = []
    build_spec_list(dependency_specs, locked_specs, specs)
    convert_specs(specs)
  end
end

def dependencies
  @dependencies ||= \
  begin
    groups = bundle_definition.groups.map {|g| g.to_s} - @bundle_without
    groups.map! { |g| g.to_sym }
    bundle_definition.dependencies.reject{|d| !d.should_include? || (d.groups & groups).empty?}
  end
end

# Build the list of specs to install by traversing each spec's dependencies,
# starting only with the included dependencies
def build_spec_list(dependencies, locked_specs, specs)
  dependency_names= dependencies.map {|item| item.name}
  locked_specs.each do |spec|
    if dependency_names.include? spec.name
      if !specs.include? spec
        specs << spec
        build_spec_list(spec.dependencies, locked_specs, specs)
      end
    end
  end
end

def convert_specs(specs)
  converted_specs = []
  specs.each do |spec|
    converted_spec = {:name => spec.name, :version => spec.version.version, :source => {:type => spec.source.class.name}}
    if spec.source.is_a?(Bundler::Source::Git)
      converted_spec[:source][:git_scope] = File.basename(spec.source.path)
      converted_spec[:source][:uri] = spec.source.options["uri"]
      converted_spec[:source][:revision] = spec.source.options["revision"]
      converted_spec[:source][:submodules] = spec.source.options["submodules"]
    end
    converted_specs << converted_spec
  end
  converted_specs
end

unless !ARGV.empty?
  puts "Usage: gemfile_parser.rb [results file] {[bundle_without]}"
  exit 1
end

results_file, bundle_without = ARGV
@bundle_without = bundle_without.split(":").map {|group| group.strip} if bundle_without
@bundle_without ||= []
# Freeze the bundle so future calls to resolve method will return only locked_specs
ENV['BUNDLE_FROZEN'] = "1"
ENV['BUNDLE_GEMFILE'] = File.expand_path("Gemfile")
File.open(results_file, 'w+') do |f|
  YAML.dump(specs, f)
end
