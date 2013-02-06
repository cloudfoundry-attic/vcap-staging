module RailsDatabaseSupport
  # Prepares a database.yml file for the app, if needed.
  # Returns the service binding that was used for the 'production' db entry.
  def configure_database
    write_database_yaml if bound_database
  end

  def database_uri
    "#{database_type}://#{credentials['username']}:#{credentials['password']}@#{credentials['host']}:#{credentials['port']}/#{credentials['database']}"
  end

  # Actually lay down a database.yml in the app's config directory.
  def write_database_yaml
    data = database_config
    conf = File.join(destination_directory, 'app', 'config', 'database.yml')
    settings = File.exists?(conf) ? YAML.load_file(conf) : {}
    settings['production']=data
    File.open(conf, 'w') do |fh|
      YAML.dump(settings, fh)
    end
    binding
  end

  def bound_database
    case bound_databases.size
    when 0
      nil
    when 1
      bound_databases.first
    else
      binding = bound_databases.detect { |b| b[:name] && b[:name] =~ /^.*production$|^.*prod$/ }
      if !binding
        raise "Unable to determine primary database from multiple. " +
              "Please bind only one database service to Rails applications."
      end
      binding
    end
  end

  def database_type
    case bound_database[:label]
      when /^mysql/
        :mysql2
      when /^postgres/
        :postgres
      else
        raise "Unable to configure unknown database: #{binding.inspect}"
    end
  end

  DATABASE_TO_ADAPTER_MAPPING = {
      :mysql => 'mysql2',
      :postgres => 'postgresql'
  }


  def database_config
      { 'adapter' =>  DATABASE_TO_ADAPTER_MAPPING[database_type], 'encoding' => 'utf8', 'pool' => 5,
        'reconnect' => false }.merge(credentials)
  end

  # return host, port, username, password, and database
  def credentials
    creds = bound_database[:credentials]
    unless creds
      raise "Database binding failed to include credentials"
    end
    { 'host' => creds[:hostname], 'port' => creds[:port],
      'username' => creds[:user], 'password' => creds[:password],
      'database' => creds[:name] }
  end

  def bound_databases
    @bound_services ||= bound_services.select { |binding| known_database?(binding) }
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

