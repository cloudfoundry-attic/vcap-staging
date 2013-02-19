require 'rubygems'

require 'yaml'
require 'yajl'
require 'erb'
require 'rbconfig'
require 'vcap/logging'

require 'tmpdir' # TODO - Replace this with something less absurd.
# WARNING WARNING WARNING - Only create temp directories when running as a separate process.
# The Ruby stdlib tmpdir implementation is beyond scary in long-running processes.
# You Have Been Warned.


require File.expand_path('../config', __FILE__)

# TODO - Separate the common staging helper methods from the 'StagingPlugin' base class, for more clarity.
# Staging plugins (at least the ones written in Ruby) are expected to subclass this. See ruby/sinatra for a simple example.
class StagingPlugin

  attr_accessor :source_directory, :destination_directory, :environment_json

  def self.staging_root
    File.expand_path('..', __FILE__)
  end

  def self.platform_config
    config_path = ENV['PLATFORM_CONFIG']
    YAML.load_file(config_path)
  end

  # Transforms lowercased/underscored word into camelcase.
  #
  # EX: camelize('foo_bar') returns 'FooBar'
  #
  def self.camelize(word)
    uc_parts = []
    for part in word.split('_')
      uc_part = part[0].upcase
      uc_part += part[1, part.length - 1] if part.length > 1
      uc_parts << uc_part
    end
    uc_parts.join
  end

  def self.load_plugin_for(framework)
    framework = framework.to_s
    plugin_path = File.join(staging_root, framework, 'plugin.rb')
    require plugin_path
    Object.const_get("#{camelize(framework)}Plugin")
  end

  # Exits the process with a nonzero status if ARGV does not contain valid
  # staging args. If you call this in-process in an app server you deserve your fate.
  def self.validate_arguments!(*args)
    source, dest, env, uid, gid = args
    argfail!(args) unless source && dest && env
    argfail!(args) unless File.directory?(File.expand_path(source))
    argfail!(args) unless File.directory?(File.expand_path(dest))
  end

  def self.argfail!(args)
    puts "Invalid arguments for staging: #{args.inspect}"
    exit 1
  end

  # Loads arguments from a file and instantiates a new instance.
  # @param  arg_filename String  Path to yaml file
  def self.from_file(cfg_filename)
    config = StagingPlugin::Config.from_file(cfg_filename)

    uid = gid = nil
    if config[:secure_user]
      uid = config[:secure_user][:uid]
      gid = config[:secure_user][:gid]
    end

    validate_arguments!(config[:source_dir],
                        config[:dest_dir],
                        config[:environment],
                        uid,
                        gid)

    self.new(config[:source_dir],
             config[:dest_dir],
             config[:environment],
             uid,
             gid)
  end

  # If you re-implement this in a subclass:
  # A) Do not change the method signature
  # B) Make sure you call 'super'
  #
  # a good subclass impl would look like:
  # def initialize(source, dest, env = nil)
  #   super
  #   whatever_you_have_planned
  #
  # NB: Environment is not what you think it is (better named app_properties?). It is a hash of:
  #   :services  => [service_binding_hash]  # See ServiceBinding#for_staging in cloud_controller/app/models/service_binding.rb
  #   :framework => {framework properties from manifest}
  #   :runtime   => {runtime properties}
  #   :resources => {                       # See App#resource_requirements or App#limits (they return identical hashes)
  #     :memory => mem limits in MB         # in cloud_controller/app/models/app.rb
  #     :disk   => disk limits in MB
  #     :fds    => fd limits
  #   }
  # end
  def initialize(source_directory, destination_directory, environment = {}, uid=nil, gid=nil)
    @source_directory = File.expand_path(source_directory)
    @destination_directory = File.expand_path(destination_directory)
    @environment = environment
    # Drop privs before staging
    # res == real, effective, saved
    @staging_gid = gid.to_i if gid
    @staging_uid = uid.to_i if uid
  end

  def logger
    @logger ||= \
    begin
      log_file = File.expand_path(File.join(log_dir, "staging.log"))
      FileUtils.mkdir_p(File.dirname(log_file))
      sink_map = VCAP::Logging::SinkMap.new(VCAP::Logging::LOG_LEVELS)
      formatter = VCAP::Logging::Formatter::DelimitedFormatter.new { data }
      sink_map.add_sink(nil, nil, VCAP::Logging::Sink::StdioSink.new(STDOUT, formatter))
      sink_map.add_sink(nil, nil, VCAP::Logging::Sink::FileSink.new(log_file, formatter))
      logger = VCAP::Logging::Logger.new('public_logger', sink_map)
      logger.log_level = ENV["DEBUG"] ? :debug : :info
      logger
    end
  end

  def app_dir
    File.join(destination_directory, "app")
  end

  def log_dir
    File.join(destination_directory, "logs")
  end

  def tmp_dir
    File.join(destination_directory, "tmp")
  end

  def script_dir
    destination_directory
  end

  def framework
    environment[:framework_info]
  end

  def stage_application
    raise NotImplementedError, "subclasses must implement a 'stage_application' method"
  end

  def environment
    @environment
  end

  def staging_command
    runtime[:staging]
  end

  def start_command
    raise NotImplementedError, "subclasses must implement a 'start_command' method that returns a string"
  end

  def stop_command
    cmds = []
    cmds << 'APP_PID=$1'
    cmds << 'APP_PPID=`ps -o ppid= -p $APP_PID`'
    cmds << 'kill -9 $APP_PID'
    cmds << 'kill -9 $APP_PPID'
    cmds.join("\n")
  end

  def local_runtime
    '%VCAP_LOCAL_RUNTIME%'
  end

  def application_memory
    if environment[:resources] && environment[:resources][:memory]
      environment[:resources][:memory]
    else
      512 #MB
    end
  end

  # The specified :runtime
  def runtime
    environment[:runtime_info]
  end

  # Environment variables specified on the app supersede those
  # set in the staging manifest for the runtime. Theoretically this
  # would allow a user to run their Rails app in development mode, etc.
  def environment_hash
    @env_variables ||= build_environment_hash
  end

  # Overridden in subclasses when the framework needs to start from a different directory.
  def change_directory_for_start
    "cd app"
  end

  def get_launched_process_pid
    "STARTED=$!"
  end

  def wait_for_launched_process
    "wait $STARTED"
  end

  def pidfile_dir
    "$DROPLET_BASE_DIR"
  end

  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    template = <<-SCRIPT
#!/bin/bash
<%= environment_statements_for(env_vars) %>
<%= after_env_before_script %>
DROPLET_BASE_DIR=$PWD
<%= change_directory_for_start %>
<%= start_command %> > $DROPLET_BASE_DIR/logs/stdout.log 2> $DROPLET_BASE_DIR/logs/stderr.log &
<%= get_launched_process_pid %>
echo "$STARTED" >> #{pidfile_dir}/run.pid
<%= wait_for_launched_process %>
    SCRIPT
    # TODO - ERB is pretty irritating when it comes to blank lines, such as when 'after_env_before_script' is nil.
    # There is probably a better way that doesn't involve making the above Heredoc horrible.
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  def generate_stop_script(env_vars = {})
    template = <<-SCRIPT
#!/bin/bash
<%= environment_statements_for(env_vars) %>
<%= stop_command %>
    SCRIPT
    ERB.new(template).result(binding)
  end

  # Generates newline-separated exports for the specified environment variables.
  # If the value of one of the keys is false or nil, it will be an 'unset' instead of an 'export'
  def environment_statements_for(vars)
    # Passed vars should overwrite common vars
    common_env_vars = { "TMPDIR" => tmp_dir.gsub(destination_directory,"$PWD") }
    vars = common_env_vars.merge(vars)
    lines = []
    vars.each do |name, value|
      if value
        lines << "export #{name}=\"#{value}\""
      else
        lines << "unset #{name}"
      end
    end
    lines.sort.join("\n")
  end

  def create_app_directories
    FileUtils.mkdir_p(app_dir)
    FileUtils.mkdir_p(log_dir)
    FileUtils.mkdir_p(tmp_dir)
  end

  def create_stop_script()
    path = File.join(script_dir, 'stop')
    File.open(path, 'wb') do |f|
      f.puts stop_script
    end
    FileUtils.chmod(0500, path)
  end

  def create_startup_script
    path = File.join(script_dir, 'startup')
    File.open(path, 'wb') do |f|
      f.puts startup_script
    end
    FileUtils.chmod(0500, path)
  end

  def copy_source_files(dest = nil)
    dest ||= app_dir
    system "cp -a #{File.join(source_directory, "*")} #{dest}"
  end

  def detection_rules
    environment[:framework_info][:detection]
  end

  def bound_services
    environment[:services] || []
  end

  # Returns all the application files that match detection patterns.
  # This excludes files that are checked for existence/non-existence.
  # Returned pathnames are relative to the app directory:
  # e.g. [sinatra_app.rb, lib/somefile.rb]
  def app_files_matching_patterns
    matching = []
    detection_rules.each do |rule|
      rule.each do |glob, pattern|
        next unless String === pattern
        full_glob = File.join(app_dir, glob)
        files = scan_files_for_regexp(app_dir, full_glob, pattern)
        matching.concat(files)
      end
    end
    matching
  end

  # Full path to the Ruby we are running under.
  def current_ruby
    File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
  end

  # Returns a set of environment clauses, only allowing the names specified.
  def minimal_env(*allowed)
    env = ''
    allowed.each do |var|
      next unless ENV.key?(var)
      env << "#{var}=#{ENV[var]} "
    end
    env.strip
  end

  # Constructs a hash containing the variables associated
  # with the app's runtime.
  def build_environment_hash
    ret = {}
    (runtime[:environment] || {}).each do |key,val|
      ret[key.to_s.upcase] = val
    end
    ret
  end

  # If the runtime info specifies a workable ruby, returns that.
  # Otherwise, returns the path to the ruby we were started with.
  def ruby
    @ruby ||= \
    begin
      rb = runtime[:executable]
      pattern = Regexp.new(Regexp.quote(runtime[:version]))
      output = get_ruby_version(rb)
      if $? == 0 && output.strip =~ pattern
        rb
      elsif "#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}" =~ pattern
        current_ruby
      else
        puts "No suitable runtime found. Needs version matching #{runtime[:version]}"
        exit 1
      end
    end
  end

  def get_ruby_version(exe)
    get_ver  = %{-e "print RUBY_VERSION,'p',RUBY_PATCHLEVEL"}
    `env -i PATH=#{ENV['PATH']} #{exe} #{get_ver}`
  end

  def insight_agent
    StagingPlugin.platform_config['insight_agent']
  end

  def scan_files(base_dir, glob)
    found = []
    base_dir << '/' unless base_dir.end_with?('/')
    Dir[glob].each do |full_path|
      matched = block_given? ? yield(full_path) : true
      if matched
        relative_path = full_path.dup
        relative_path[base_dir] = ''
        found.push(relative_path)
      end
    end
    found
  end

  def scan_files_for_regexp(base_dir, glob, pattern)
    scan_files(base_dir, glob) do |path|
      matched = false
      File.open(path, 'rb') do |f|
        matched = true if f.read.match(pattern)
      end
      matched
    end
  end
end
