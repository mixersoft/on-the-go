'use strict'

###*
 # @ngdoc service
 # @name ionBlankApp.pushNotification
 # @description
 # wrapper for pushNotification plugin, register installation with push server on PARSE
 # handle push notification events:  adds badges, notifications to iOS notification panel
###

angular.module 'snappi.notification.push', [
  'ionic', 
  'snappi.util'
  'onTheGo.backend'
]
.factory( 'pushNotificationPluginSvc', [ 
  '$rootScope', '$location', '$q', '$log', '$http'
  '$cordovaPush', '$cordovaMedia'
  'notifyService'
  'PARSE_CREDENTIALS', 'deviceReady'
  
  ($rootScope, $location, $q, $log, $http, $cordovaPush, $cordovaMedia, notify, PARSE_CREDENTIALS, deviceReady)->

    notifyPayloads = {
      'top-picks':
        aps:
          alert: 
            title: 'Great Shot!'
            body: "We've got some Top Picks for you - check them out."
          badge: null # new picks
          sound: 'default'
          'content-available': 1
        target: 'app.top-picks.top-picks'
      'upload-upcoming':
        aps:
          alert: 
            title: 'Bon Voyage!'
            body: 'You scheduled an order for a trip that begins today. Be sure to enable the Uploader.'
          sound: 'default'
        target: 'app.uploader'
      'upload-queued':
        aps:
          alert: 
            title: 'Ready for Upload'
            body: "We have your order and are ready for photos. Visit the Uploader to get started."
          sound: 'default'
        target: 'app.uploader'
      'upload-missing':
        aps:
          alert: 
            title: "We have a problem..."
            body: "We have your order but no photos. Be sure to enable the Uploader.'"
          sound: 'default'
        target: 'app.uploader'        
    }



    $rootScope.$on '$cordovaPush:notificationReceived', (event, notification)->
      console.log "notification received, JSON="+JSON.stringify notification
      $log.debug( '$cordovaPush:notificationReceived', notification )
      if ionic.Platform.isAndroid()
        self.handleAndroid( notification )
      else if ionic.Platform.isIOS()
        self.handleIOS( notification )
      return

    _localStorageDevice = null 

    self = {
      # check existing Parse Installation object
      ###
      # @param $localStorageDevice object, place to check for/save existing Parse installation
      #   keys; ['objectId', 'deviceType', 'installationId', 'owner', 'username']
      #   NOTE: should be saved to $localStorage['device']
      ###
      initialize: ($localStorageDevice)->
        return self if deviceReady.device().isBrowser == true

        _localStorageDevice = $localStorageDevice
        self.isReady = true
        console.log "pushNotificationPluginSvc initialized"

        # debug only
        self['messages'] = {}
        _.each _.keys( notifyPayloads ), (key)->
          self['messages'][key] = JSON.stringify notifyPayloads[key]
          return

        return self

      registerP: ()->
        if !self.isReady
          $log.warn("WARNING: attempted to register device before plugin intialization.") 
          return $q.reject("pushNotify plugin not initialized")

        if _localStorageDevice?['pushInstall']?
          isOK = true
          isOK = isOK && _localStorageDevice['pushInstall'].ownerId?
          isOK = isOK && _localStorageDevice['pushInstall'].deviceId == deviceReady.device().deviceId
          isOK = isOK && _localStorageDevice['pushInstall'].installationId == Parse._getInstallationId()
          if isOK
            console.log("pushInstall OK")
            return $q.when('done') 

        if ionic.Platform.isAndroid()
          config = {
              "senderID": "YOUR_GCM_PROJECT_ID" #  // REPLACE THIS WITH YOURS FROM GCM CONSOLE - also in the project URL like: https://console.developers.google.com/project/434205989073
          }
        else if ionic.Platform.isIOS()
          config = {
              "badge": "true",
              "sound": "true",
              "alert": "true"
          }
        return $cordovaPush.register(config).then (result)->
            $log.debug("Register success " + result)
            if ionic.Platform.isIOS()
              self.storeDeviceTokenP {
                  type: 'ios'
                  deviceToken: result
                } 
            else if ionic.Platform.isAndroid()
              # ** NOTE: Android regid result comes back in the pushNotificationReceived
              angular.noop()
            return true
          , (err)->
            $log.error('register', err)
            return $q.reject("pushNotify $cordovaPush register error")


      handleIOS: (notification)->
        # The app was already open but we'll still show the alert 
        # and sound the tone received this way. If you didn't check
        # for foreground here it would make a sound twice, once when 
        # received in background and upon opening it from clicking
        # the notification when this code runs (weird).
        # $log.debug "handleIOS()", notification

        # looks like: Object
        #   body: "We have your order and are ready for photos. Visit the Uploader to get started."
        #   foreground: "1"
        #   sound: "default"
        #   target: "app.uploader"
        #   title: "Ready for Upload"
        if notification.foreground == '1'
          if notification.sound
            media = $cordovaMedia.newMedia(notification.sound).then ()->
                media.play()
                return
              , (err)->
                $log.error "Play media error", err

          if notification.badge
            $cordovaPush.setBadgeNumber(notification.badge).then (result)->
                $log.debug "Set badge success", result
                return
              , (err)->
                $log.error "Set badge error", err
        else 
          # sound, badge should be set in background by notification Center
          angular.noop()

        msg = {
          target : notification.target
        }
        if notification.body?
          msg['title'] = notification.title
          msg['message'] = notification.body
        else 
          msg['message'] = notification.alert
        notify.message msg,'info', 10000

        return if !notification.target

        # handle state transition
        if notification.target[0...4] == 'app.'
          $rootScope.$state.transitionTo( notification.target ) 
        else
          $location.path(notification.target)  
        return       

      handleAndroid: (notification)->
        # // ** NOTE: ** You could add code for when app is in foreground or not, or coming from coldstart here too
        # //             via the console fields as shown.
        console.log("In foreground " + notification.foreground  + " Coldstart " + notification.coldstart);
        if notification.event == "registered"
          self.storeDeviceTokenP {
                  type: 'android'
                  deviceToken: result
                } 
        else if notification.event == "message"
          notify.message notification.message
          $log.debug 'handleAndroid', notification
        else if notification.event == "error"
          notify.message notification.message, 'error'
          $log.error 'Error: handleAndroid', notification
        return

      storeDeviceTokenP: (options)->
        throw "storeDeviceTokenP(): Error invalid options" if `options==null`

        postData = {
          "deviceId": deviceReady.device().id
          "deviceType": options.type,
          "deviceToken": options.deviceToken,
          "installationId" : Parse._getInstallationId(),
          "channels": [""] 
        }

        if $rootScope.sessionUser?
          postData["ownerId"] = $rootScope.sessionUser.id || null
          postData["username"] = $rootScope.sessionUser.get('username')

        # TODO: move to otgParse?
        xhrOptions = {
          url: "https://api.parse.com/1/installations",
          method: "POST",
          data: postData,
          headers:  
            "X-Parse-Application-Id": PARSE_CREDENTIALS.APP_ID,
            "X-Parse-REST-API-Key": PARSE_CREDENTIALS.REST_API_KEY,
            "Content-Type": "application/json"
        }
        return $http(xhrOptions)
          .success (data, status)->
            _localStorageDevice['pushInstall'] = _.pick data, ['objectId', 'deviceType', 'installationId', 'ownerId', 'username']
            $log.debug("Parse installation saved", [data, status])
            return data
          .error (data, status)->
            $log.error("Error: saving Parse installation", [data, status])
            return $q.reject("pushNotify register error saving to Parse")


    }
    return self


  ])