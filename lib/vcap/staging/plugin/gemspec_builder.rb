require "shellwords"

require File.expand_path('../secure_operations', __FILE__)

class GemspecBuilder
  include SecureOperations

  attr_reader :gemspec_path, :filename, :base_dir

  def initialize(gemspec_path, ruby_cmd, logger)
    @gemspec_path = Shellwords.escape(gemspec_path)
    @filename = File.basename(@gemspec_path)
    @base_dir = File.dirname(@gemspec_path)
    @ruby_cmd = ruby_cmd
    @logger = logger
  end

  def requires_build?
    # Check if gemspec has extensions
    # If our ruby_cmd runs ruby 1.8 we need to require rubygems
    cmd = "#{@ruby_cmd} -rrubygems -e 'puts Gem::Specification.load(\"#{@gemspec_path}\").extensions.size'"
    exit_code, output = run_secure(cmd, base_dir)
    exit_code == 0 && output.to_i != 0
  end

  # Overwrite current gemspec with the evaluated code (to_ruby_for_cache)
  # We do these updates because currently git is not available in PATH on DEA
  # and many gemspecs call git commands like `git ls-files`
  def update
    cmd = "#{@ruby_cmd} -rrubygems -e 'puts Gem::Specification.load(\"#{@gemspec_path}\").to_ruby_for_cache'"
    exitstatus, spec = run_secure(cmd, base_dir)
    File.open(@gemspec_path, "w") { |f| f.write(spec) } if exitstatus == 0
  end

  def update_from_path(new_gemspec)
    FileUtils.copy_entry(new_gemspec, @gemspec_path)
  rescue
    @logger.error "Failed updating gemspec #{@gemspec_path}"
  end

  def build
    gem_path = nil
    Dir.chdir(base_dir) do
      cmd = "#{@ruby_cmd} -S gem build '#{@gemspec_path}' --force"
      run_secure(cmd, base_dir)
      gem_path = Dir[File.join(base_dir, "*.gem")].sort_by{|f| File.mtime(f)}.last
    end
    gem_path
  end
end