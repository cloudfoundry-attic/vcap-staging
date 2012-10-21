# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "broken-compile"
  s.version     = "0.0.1"
  s.authors     = ["Foo Bar"]
  s.email       = ["foo@example.com"]
  s.homepage    = "http://example.com/"
  s.summary     = %q{
    A broken gem.
  }
  s.description = %q{
    A really broken gem.
  }
  s.date        = "2012-05-02"
  s.extensions = ["ext/extconf.rb"]
  s.files         = ["README", "lib/broken-gem.rb", "ext/extconf.rb"]
  s.test_files    = []
  s.require_paths = ["lib"]
end
