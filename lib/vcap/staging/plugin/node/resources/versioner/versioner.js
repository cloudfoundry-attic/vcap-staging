;(function () {

  function versioner() {}

  module.exports = versioner
  versioner.usage = "node versioner.js --node-range=range "+
    "--npm-range=range --node-version=version --npm-version=version"

  var nodeRangeReg = new RegExp("^--node-range=(.*)$")
    , npmRangeReg = new RegExp("^--npm-range=(.*)$")
    , nodeVersionReg = new RegExp("^--node-version=(.*)$")
    , npmVersionReg = new RegExp("^--npm-version=(.*)$")
    , pkg, nodeRange, npmRange, nodeVersion, npmVersion, opt

  process.argv.forEach(function (arg) {
    if (opt = arg.match(nodeRangeReg)) nodeRange = opt[1].replace(/\\/g, "")
    else if (opt = arg.match(npmRangeReg)) npmRange = opt[1].replace(/\\/g, "")
    else if (opt = arg.match(nodeVersionReg)) nodeVersion = opt[1]
    else if (opt = arg.match(npmVersionReg)) npmVersion = opt[1]
  })

  if (nodeRange == null || npmRange == null || !nodeVersion || !npmVersion) {
    failProcess("Usage: "+versioner.usage+"\n")
  }

  if (nodeRange == "" && npmRange == "") {
    process.exit(0)
  }

  var semver = require("semver")

  if (nodeRange != "" && !semver.satisfies(nodeVersion, nodeRange)) {
    failProcess("Node version requirement "+nodeRange+" is not compatible "+
      "with the current node version "+nodeVersion)
  }

  if (npmRange != "" && !semver.satisfies(npmVersion, npmRange)) {
    failProcess("Npm version requirement "+npmRange+" is not compatible "+
      "with the current npm version "+npmVersion)
  }

  function failProcess (err) {
    process.stdout.write(err)
    process.exit(1)
  }

})()
