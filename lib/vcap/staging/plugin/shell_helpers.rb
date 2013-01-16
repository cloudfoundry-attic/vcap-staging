require "open3"

module ShellHelpers
  def run_and_check(command)
    output = nil
    exitstatus = nil

    Open3.popen2e(*command.split(/\s+/)) do |stdin, stdout_and_stderr, wait_thr|
      output = stdout_and_stderr.read
      exitstatus = wait_thr.value.exitstatus
    end

    logger.info output

    [output, exitstatus == 0]
  end
end