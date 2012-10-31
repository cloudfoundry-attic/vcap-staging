module JavaDatabaseSupport
  SERVICE_DRIVER_HASH = {
    "mysql" => '*mysql-connector-java-*.jar',
    "postgresql" => '*postgresql-*.jdbc*.jar'
  }

  def copy_service_drivers(driver_dest,services)
    return if services == nil
    drivers = []
    services.each { |svc|
      db_label = svc[:label]
      db_key = db_label.index('-') ? db_label.slice(0, db_label.index('-')) : db_label
      if SERVICE_DRIVER_HASH.has_key?(db_key)
        drivers << db_key
      end
    }
    drivers.each { |driver|
      copy_jar SERVICE_DRIVER_HASH[driver], driver_dest
    } if drivers
  end

  private
  def copy_jar jar, dest
    resource_dir = File.join(File.dirname(__FILE__), 'resources')
    Dir.chdir(resource_dir) do
      jar_path = File.expand_path(Dir.glob(jar).first)
      FileUtils.mkdir_p dest
        Dir.chdir(dest) do
	  FileUtils.cp(jar_path, dest) if Dir.glob(jar).empty?
	end
    end
  end
end
