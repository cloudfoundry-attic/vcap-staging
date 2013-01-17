require "open3"

module ShellHelpers
  def run_and_log(command, capture = [:out, :err])
    out, status = Open3.capture2e(command)

    logger.info out

    [out, status == 0]
  end
end