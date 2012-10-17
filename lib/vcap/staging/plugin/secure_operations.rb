require "shellwords"

# This module contains methods for performing tasks and
# setting file permissions/ownership using a secure user
# Classes including this module should set the instance variable
# @staging_uid to the ID of a secure user, if one should be used.
module SecureOperations

  # Run a process as a secure user, if @staging_uid is set.
  # Otherwise, process is run as current user
  # Use the "where" variable to set the process working dir,
  def run_secure(cmd, where, options={})
    exitstatus = nil
    output = nil

    secure_file(where)
    begin
      if @staging_uid
        if options[:secure_group]
          cmd ="sudo -u '##{@staging_uid}' sg #{secure_group} -c \"cd #{where} && #{cmd}\" 2>&1"
        else
          cmd = "cd #{where} && sudo -u '##{@staging_uid}' #{cmd} 2>&1"
        end
      else
        cmd = "cd #{where} && #{cmd} 2>&1"
      end

      IO.popen(cmd) do |io|
        output = io.read
      end

      exitstatus = $?.exitstatus

      # Kill any stray processes that the cmd may have created
      `sudo -u '##{@staging_uid}' pkill -9 -U #{@staging_uid} 2>&1` if @staging_uid
    ensure
      begin
        unsecure_file(where)
      rescue => e
        @logger.error "Failed to unsecure dir: #{e}"
      end
    end

    [ exitstatus, output ]
  end

  # Change permissions and ownership of specified file
  # to secure user, if @staging_uid is set
  def secure_file(file)
    secure_chmod(file)
    secure_chown(file)
  end

  def secure_chmod(file)
    if @staging_uid
      chmod_output = `/bin/chmod -R 0755 #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chmodding dir: #{chmod_output}"
      end
    end
  end

  def secure_chown(file)
    if @staging_uid
      chown_user = @staging_gid ? "#{@staging_uid}:#{@staging_gid}" : @staging_uid
      chown_output = `sudo /bin/chown -R #{chown_user} #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chowning dir: #{chown_output}"
      end
    end
  end

  # Change ownership of specified file
  # to current user
  def unsecure_file(file)
    if @staging_uid
      chown_user = `id -u`.chomp
      if @staging_gid
        user_group = `id -g`.chomp
        chown_user = "#{chown_user}:#{user_group}"
      end
      chown_output = `sudo /bin/chown -R #{chown_user} #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chowning dir: #{chown_output}"
      end
    end
  end

  # Change ownership of file back to current user
  # and delete file
  def secure_delete(file)
    if File.exists?(file)
      unsecure_file(file)
      FileUtils.rm_rf(file)
    end
  end

  def secure_group
    group_name = `awk -F: '{ if ( $3 == #{@staging_gid} ) { print $1 } }' /etc/group`
    group_name.chomp
  end

  def shellescape(word)
    Shellwords.escape(word)
  end
end
