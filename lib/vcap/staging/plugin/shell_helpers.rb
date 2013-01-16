module ShellHelpers
  def run_and_check(command)
    output = `#{command}`
    return_code = $? == 0
    logger.info output
    [output, return_code]
  end
end