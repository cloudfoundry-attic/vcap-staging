require "shellwords"

require File.expand_path('../secure_operations', __FILE__)

class GemSpec
  include SecureOperations

  attr_reader :path, :filename, :base

  def initialize(gemspec_path, ruby_cmd, logger)
    @path = Shellwords.escape(gemspec_path)
    @filename = File.basename(@path)
    @base = File.dirname(@path)
    @ruby_cmd = ruby_cmd
    @logger = logger
  end

  def requires_build?
    base = File.dirname(@path)
    # will fail if spec has no extensions
    cmd = "#{@ruby_cmd} -e 'Gem::Specification.load(\"#{@path}\").extensions.fetch(0)' 2>/dev/null"
    run_secure?(cmd, base)
  end

  # Overwrite current gemspec with the evaluated code
  # We do these updates because currently git is not available in PATH on DEA
  # and many gemspecs call git commands
  def update
    base = File.dirname(@path)
    cmd = "#{@ruby_cmd} -lrubygems -e 'puts Gem::Specification.load(\"#{@path}\").to_ruby_for_cache'"
    exitstatus, spec = run_secure(cmd, base)
    File.open(@path, "w") { |f| f.write(spec) } if exitstatus == 0
  end

  def update_from_path(new_gemspec)
    begin
      FileUtils.copy_entry(new_gemspec, @path)
    rescue
      @logger.error "Failed updating gemspec #{@path}"
    end
  end

  def build
    gem_path = nil
    Dir.chdir(base) do
      cmd = "#{@ruby_cmd} -S gem build '#{@path}' --force"
      run_secure(cmd, @base)
      gem_path = Dir[File.join(base, "*.gem")].sort_by{|f| File.mtime(f)}.last
    end
    gem_path
  end
end