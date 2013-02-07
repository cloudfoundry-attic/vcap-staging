$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'vcap/staging/version'

gemspec = Gem::Specification.new do |s|
  s.name         = 'vcap_staging'
  s.version      = VCAP::Staging::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Plugins responsible for creating executable droplets'
  s.description  = "Staging plugins take a user's application and produce a bundle that can be executed on a DEA"
  s.authors      = ['CloudFoundry']
  s.email        = 'support@vmware.com'
  s.homepage     = 'http://www.cloudfoundry.com'

  s.add_dependency('nokogiri', '>= 1.4.4')
  s.add_dependency('rake')
  s.add_dependency('yajl-ruby', '>= 0.7.9')
  s.add_dependency('vcap_logging', '= 0.1.4')

  s.add_development_dependency('rspec')
  s.add_development_dependency('pry')
  s.add_development_dependency('pry-remote')
  s.add_development_dependency('rb-readline')

  s.add_dependency('uuidtools', "~> 2.1.2")

  s.executables  = []
  s.bindir       = 'bin'
  s.require_path = 'lib'

  s.files        = %w(Rakefile bin/run_plugin) + Dir.glob("lib/**/*") + Dir.glob("vendor/**/*")
end
