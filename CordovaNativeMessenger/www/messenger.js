
cordova.define('cordova/plugin/Messenger', function(require, exports, module) {
	var exec = require('cordova/exec');
	var Messenger = function(){};

	Messenger.prototype.bindListener = function(listener) {
		exec(listener, listener, "CordovaNativeMessenger", "bindListener", []);
	};

	Messenger.prototype.mapAssetsLibrary = function(callback) {
		exec(callback, null, "CordovaNativeMessenger", "mapAssetsLibrary", []);
	};

	var plugin = new Messenger();

	module.exports = plugin;
});

var Messenger = cordova.require("cordova/plugin/Messenger");

module.exports = Messenger;