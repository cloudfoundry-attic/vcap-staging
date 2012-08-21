module RailsDatabaseSupport
  # Prepares a database.yml file for the app, if needed.
  # Returns the service binding that was used for the 'production' db entry.
  def configure_database
    bindings = bound_databases
    case bindings.size
    when 0
      # nothing to do
    when 1
      write_database_yaml(bindings.first)
    else
      configure_multiple_databases(bindings)
    end
  end

  # Actually lay down a database.yml in the app's config directory.
  def write_database_yaml(binding)
    data = database_config_for(binding)
    conf = File.join(destination_directory, 'app', 'config', 'database.yml')
    settings = File.exists?(conf) ? YAML.load_file(conf) : {}
    settings['production']=data
    File.open(conf, 'w') do |fh|
      YAML.dump(settings, fh)
    end
    binding
  end

  def configure_multiple_databases(bindings)
    # Where possible, select one named '^.*production' or 'prod' before failing.
    production_db = bindings.detect { |b| b[:name] && b[:name] =~ /^.*production$|^.*prod$/ }
    if production_db
      write_database_yaml(production_db)
    else
      raise "Unable to determine primary database from multiple.  " +
        "Please bind only one database service to Rails applications."
    end
  end

  def database_config_for(binding)
    case binding[:label]
    when /^mysql/
      { 'adapter' => 'mysql2', 'encoding' => 'utf8', 'pool' => 5,
        'reconnect' => false }.merge(credentials_from(binding))
    when /^postgresql/
      { 'adapter' => 'postgresql', 'encoding' => 'utf8', 'pool' => 5,
        'reconnect' => false }.merge(credentials_from(binding))
    else
      raise "Unable to configure unknown database: #{binding.inspect}"
    end
  end

  # return host, port, username, password, and database
  def credentials_from(binding)
    creds = binding[:credentials]
    unless creds
      raise "Database binding failed to include credentials"
    end
    { 'host' => creds[:hostname], 'port' => creds[:port],
      'username' => creds[:user], 'password' => creds[:password],
      'database' => creds[:name] }
  end

  def bound_databases
    bound_services.select { |binding| known_database?(binding) }
  end

  def known_database?(binding)
    if label = binding[:label]
      case label
      when /^mysql/
        binding
      when /^postgresql/
        binding
      end
    end
  end
end

