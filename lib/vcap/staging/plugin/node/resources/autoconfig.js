process.argv[1] = require("path").resolve("@@MAIN_FILE@@");
require("cf-autoconfig");
process.nextTick(require("module").Module.runMain);