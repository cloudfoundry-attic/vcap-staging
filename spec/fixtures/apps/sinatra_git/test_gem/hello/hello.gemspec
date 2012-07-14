Gem::Specification.new do |s|
  s.name = "hello"
  s.author = "Jesse Zhang"
  s.version = "0.0.1"
  s.extensions = ["ext/extconf.rb"]
  s.files = ["ext/hello.c", "ext/extconf.rb"]
end
