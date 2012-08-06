http = require "http"
name = process.argv[2]
http.createServer (req, res) ->
  res.writeHead 200, "Content-Type": "text/plain"
  res.end "Hello, #{name}!"
.listen 8000

console.log "Hello, #{name}!"
