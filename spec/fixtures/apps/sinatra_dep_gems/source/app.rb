require "sinatra"
require "v8"

cxt = V8::Context.new

get "/" do
  cxt['foo'] = "Hello world!"
  cxt.eval('foo')
end