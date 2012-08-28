require 'tmpdir'

module StagingSpecHelpers
  AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.5.jar'
  MYSQL_DRIVER_JAR = 'mysql-connector-java-5.1.12-bin.jar'
  POSTGRESQL_DRIVER_JAR = 'postgresql-9.0-801.jdbc4.jar'
  INSIGHT_AGENT = 'cf-tomcat-agent-javaagent-1.7.1.RELEASE'
  AUTO_CONFIG_GEM_VERSION = '0.0.4'

  # Importantly, this returns a Pathname instance not a String.
  # This allows you to write: app_fixture_base_directory.join('subdir', 'subsubdir')
  def app_fixture_base_directory
    Pathname.new(File.expand_path('../../fixtures/apps', __FILE__))
  end

  # Set the app fixture that the current spec will use.
  # TODO - Ensure that this is is cleared between groups.
  def app_fixture(name)
    @app_fixture = name.to_s
  end

  def app_source(tempdir = nil)
    unless @app_fixture
      raise "Call 'app_fixture :name_of_app' before using app_source"
    end
    app_dir = app_fixture_base_directory.join(@app_fixture)
    if File.exist?(warfile = app_dir.join('source.war'))
      # packaged WAR file
      tempdir ||= Dir.mktmpdir(@app_fixture)
      output = `unzip -q #{warfile} -d #{tempdir} 2>&1`
      unless $? == 0
        raise "Failed to unpack #{@app_fixture} WAR file: #{output}"
      end
      tempdir.to_s
    else
      # exploded directory
      app_dir.join('source').to_s
    end
  end

  # If called without a block, returns the staging output directory as a string.
  # You must manually clean up the directory thus created.
  # If called with a block, yields the staged directory as a Pathname, and
  # automatically deletes it when the block returns.
  def stage(env = {})
    raise "Call 'app_fixture :name_of_app' before staging" unless @app_fixture
    plugin_klass = StagingPlugin.load_plugin_for(env[:framework_info][:name])
    working_dir = Dir.mktmpdir("#{@app_fixture}-staged")
    source_tempdir = nil
    # TODO - There really needs to be a single helper to track tempdirs.
    source_dir = case env[:framework_info][:name]
                 when /spring|grails|lift|java_web/
                   source_tempdir = Dir.mktmpdir(@app_fixture)
                   app_source(source_tempdir)
                 else
                   app_source
                 end
    env[:environment] ||= []
    runtime_name = env[:runtime_info][:name].upcase
    if ENV["VCAP_RUNTIME_#{runtime_name}"]
      env[:runtime_info][:executable] = ENV["VCAP_RUNTIME_#{runtime_name}"]
      # When we aren't doing anything patchlevel specific, the runtime
      # version can be overridden here
      if ENV["VCAP_RUNTIME_#{runtime_name}_VER"]
        env[:runtime_info][:version] = ENV["VCAP_RUNTIME_#{runtime_name}_VER"]
      end
    end
    stager = plugin_klass.new(source_dir, working_dir, env)
    stager.stage_application
    return working_dir unless block_given?
    Dir.chdir(working_dir) do
      yield Pathname.new(working_dir), Pathname.new(source_dir)
    end
    nil
  ensure
    FileUtils.rm_r(working_dir) if working_dir
    FileUtils.rm_r(source_tempdir) if source_tempdir
  end
end