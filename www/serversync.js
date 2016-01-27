/*global cordova, module*/

var exec = require("cordova/exec")

/*
 * Format of the returned value:
 * {
 *    "connectUrl": "...",
 *    "isSkipAuth": true/false,
 *    "googleWebAppClientID": "...",
 *    "ios": {
 *       "googleClientID": "...",
 *       "googleClientSecret": "...",
 *       "parseAppID": "...",
 *       "parseClientID": "...",
 *    }
 * }
 */

var ServerSync = {
    init: function (config, successCallback, errorCallback) {
        exec(successCallback, errorCallback, "ServerSync", "init", []);
    },
    forceSync: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, "ServerSync", "forceSync", []);
    }
}

module.exports = ServerSync;
