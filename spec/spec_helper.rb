require 'vcap/staging/plugin/staging_plugin'
require 'rr'

require File.expand_path('../support/custom_matchers', __FILE__)
require File.expand_path('../support/staging_spec_helpers', __FILE__)

# Created as needed, removed at the end of the spec run.
# Allows us to override staging paths.
STAGING_TEMP = Dir.mktmpdir

RSpec.configure do |config|
  config.include StagingSpecHelpers
  config.mock_with :rr
end

at_exit do
  if File.directory?(STAGING_TEMP)
    FileUtils.rm_r(STAGING_TEMP)
  end
end
