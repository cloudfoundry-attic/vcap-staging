require "sinatra"
require "yajl"

config = Yajl::Parser.parse(File.new(File.expand_path("../config.json", __FILE__), "r"))

get "/" do
  config["message"]
end
