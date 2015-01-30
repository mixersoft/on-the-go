const pluginName = "CordovaNativeMessenger";

cordova.define('cordova/plugin/Messenger', function(require, exports, module) {
	var exec = require('cordova/exec');
	
	var Messenger = function() {
    	this.listeners = {};
    	
    	exec(this.nativeListener.bind(this), null, pluginName, "bindListener", []);
	};
	
	Messenger.prototype.nativeListener = function(message) {
        if(this.listeners[message.command]) {
            this.listeners[message.command](message.data);
        }
	};
	
	Messenger.prototype.on = function(command, callback) {
    	this.listeners[command] = callback;
	}

	Messenger.prototype.lastImageAssetID = function(data, onSuccess, onError) {
		exec(onSuccess, onError, "CordovaNativeMessenger", "lastImageAssetID", [data]);
	};

	Messenger.prototype.scheduleAssetsForUpload = function(data, onSuccess, onError) {
		exec(onSuccess, onError, "CordovaNativeMessenger", "scheduleAssetsForUpload", [data]);
	};
	
	Messenger.prototype.unscheduleAssetsForUpload = function(data, onSuccess, onError) {
		exec(onSuccess, onError, "CordovaNativeMessenger", "unscheduleAssetsForUpload", [data]);
	};

	Messenger.prototype.mapAssetsLibrary = function(callback) {
		exec(callback, null, "CordovaNativeMessenger", "mapAssetsLibrary", []);
	};

	Messenger.prototype.getPhotoById =function(identifier, options, onSuccess, onError) {
		exec(onSuccess, onError, "CordovaNativeMessenger", "getPhotoById", [identifier, options]);
	}
               
  Messenger.prototype.getScheduledAssets = function(onSuccess) {
      exec(onSuccess, null, "CordovaNativeMessenger", "getScheduledAssets", []);
  }
    
  Messenger.prototype.unscheduleAllAssets = function(onSuccess) {
      exec(onSuccess, null, "CordovaNativeMessenger", "unscheduleAllAssets", []);
  }
	
	var plugin = new Messenger();

	module.exports = plugin;
});

var Messenger = cordova.require("cordova/plugin/Messenger");

module.exports = Messenger;