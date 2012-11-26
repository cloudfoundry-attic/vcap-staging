require "shellwords"
require "open3"

# This module contains methods for performing tasks and
# setting file permissions/ownership using a secure user
# Classes including this module should set the instance variable
# @uid to the ID of a secure user, if one should be used.
module SecureOperations

  # Run a process as a secure user, if @uid is set.
  # Otherwise, process is run as current user
  # Use the "where" variable to set the process working dir,
  def run_secure(cmd, where = Dir.pwd, options={})
    output = nil
    exitstatus = nil

    secure_file(where)
    begin
      shell_argv = []

      if @uid
        shell_argv.push("sudo", "-u", "##{@uid}")
        if options[:secure_group]
          shell_argv.push("sg", secure_group)
        end
      end

      shell_argv.push("/bin/sh")

      Open3.popen2e(*shell_argv) do |stdin, stdout_and_stderr, wait_thr|
        stdin.puts("cd #{where}")
        stdin.puts(cmd)
        stdin.close

        output = stdout_and_stderr.read
        output = output.chomp unless output.nil?
        exitstatus = wait_thr.value.exitstatus
      end

      # Kill any stray processes that the cmd may have created
      `sudo -u '##{@uid}' pkill -9 -U #{@uid} 2>&1` if @uid
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
  # to secure user, if @uid is set
  def secure_file(file)
    secure_chmod(file)
    secure_chown(file)
  end

  def secure_chmod(file)
    if @uid
      chmod_output = `/bin/chmod -R 0755 #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chmodding dir: #{chmod_output}"
      end
    end
  end

  def secure_chown(file)
    if @uid
      chown_user = @gid ? "#{@uid}:#{@gid}" : @uid
      chown_output = `sudo /bin/chown -R #{chown_user} #{file} 2>&1`
      if $?.exitstatus != 0
        raise "Failed chowning dir: #{chown_output}"
      end
    end
  end

  # Change ownership of specified file
  # to current user
  def unsecure_file(file)
    if @uid
      chown_user = `id -u`.chomp
      if @gid
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
    group_name = `awk -F: '{ if ( $3 == #{@gid} ) { print $1 } }' /etc/group`
    group_name.chomp
  end

  def shellescape(word)
    Shellwords.escape(word)
  end
end
