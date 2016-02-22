/*global cordova, module*/

var exec = require("cordova/exec")

var ServerSync = {
    forceSync: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, "ServerSync", "forceSync", []);
    }
}

module.exports = ServerSync;
