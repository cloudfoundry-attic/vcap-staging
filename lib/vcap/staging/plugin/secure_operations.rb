module SecureOperations

  def run_secure(cmd, where="/")
    pid = fork
    if pid
      # Parent, wait for staging to complete
      Process.waitpid(pid)
      child_status = $?

      # Kill any stray processes that the cmd may have created
      `sudo -u '##{@uid}' pkill -9 -U #{@uid} 2>&1` if @uid

      if child_status.exitstatus != 0
        return false
      else
        return true
      end
    else
      close_fds
      if @uid
        cmd = "cd #{where} && sudo -u '##{@uid}' #{cmd}"
      else
        cmd = "cd #{where} && #{cmd}"
      end
      exec(cmd)
    end
  end

  def secure_file(file)
    if @uid
      chmod_output = `/bin/chmod -R 0755 #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chmodding dir: #{chmod_output}"
      end
      chown_output = `sudo /bin/chown -R #{@uid} #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chowning dir: #{chown_output}"
      end
    end
  end

  def unsecure_file(file)
    if @uid
      user = `whoami`.chomp
      chown_output = `sudo /bin/chown -R #{user} #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chowning dir: #{chown_output}"
      end
    end
  end

  def secure_delete(file)
    user = `whoami`.chomp
    `sudo /bin/chown -R #{user} #{file}` if @uid
     FileUtils.rm_rf(file)
  end

  private
  def close_fds
    3.upto(get_max_open_fd) do |fd|
      begin
        IO.for_fd(fd, "r").close
      rescue
      end
    end
  end

  def get_max_open_fd
    max = 0

    dir = nil
    if File.directory?("/proc/self/fd/") # Linux
      dir = "/proc/self/fd/"
    elsif File.directory?("/dev/fd/") # Mac
      dir = "/dev/fd/"
    end

    if dir
      Dir.foreach(dir) do |entry|
        begin
          pid = Integer(entry)
          max = pid if pid > max
        rescue
        end
      end
    else
      max = 65535
    end
    max
  end
end
