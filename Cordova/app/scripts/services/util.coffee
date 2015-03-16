'use strict'

###*
 # @ngdoc service
 # @name ionBlankApp.util
 # @description
 # # utility services
###


angular.module 'snappi.util', ['ionic', 'ngCordova', 'ngStorage']
.factory 'deviceReady', [
  '$q', '$timeout',  '$ionicPlatform', '$cordovaNetwork', '$localStorage'
  ($q, $timeout, $ionicPlatform, $cordovaNetwork, $localStorage)->

    _promise = null
    _timeout = 2000
    _contentWidth = null 
    _device = {}
    _device = 
      if $localStorage['device']?
      then angular.copy( $localStorage['device'] )
      else {    # initialize
        id: '00000000000'
        platform: {}
        isDevice: null
        isBrowser: null
      }

    self = {

      device: ()->
        return _device

      contentWidth: (force)->
        return _contentWidth if _contentWidth && !force
        return _contentWidth = document.getElementsByTagName('ion-side-menu-content')[0]?.clientWidth
          
      waitP: ()->
        return _promise if _promise
        deferred = $q.defer()
        _cancel = $timeout ()->
            # console.warn "$ionicPlatform.ready TIMEOUT!!!"
            return deferred.reject("ERROR: ionicPlatform.ready does not respond")
          , _timeout
        $ionicPlatform.ready ()->
          $timeout.cancel _cancel
          platform = _.defaults ionic.Platform.device(), {
            available: false
            cordova: false
            platform: 'browser'
            uuid: 'browser'
          }
          $localStorage['device'] = {
            id: platform.uuid
            platform : platform
            isDevice: ionic.Platform.isWebView()
            isBrowser: ionic.Platform.isWebView() == false
           }
          _device = angular.copy $localStorage['device']
          # console.log "$ionicPlatform reports deviceReady, device.id=" + $localStorage['device'].id
          return deferred.resolve( _device )
        return _promise = deferred.promise

      isOnline: ()->
        return true if $localStorage['device'].isBrowser
        return !$cordovaNetwork.isOffline()
    }
    return self
]
.service 'snappiTemplate', [
  '$q', '$http', '$templateCache'
  ($q, $http, $templateCache)->
    self = this
    # templateUrl same as directive, do NOT use SCRIPT tags
    this.load = (templateUrl)->
      $http.get(templateUrl, { cache: $templateCache})
      .then (result)->
        console.log 'HTML Template loaded, src=', templateUrl
    return

]
.factory 'appConsole', [
  '$ionicModal', '$q'
  ($ionicModal, $q)->

    self = {
      _modal: null
      _message: null
      log: (message)->
        self._message = message if _.isString message
        self._message = JSON.stringify message, null, 2 if _.isObject message
      show: (message)->
        self.log(message) if message
        return self._modal.show() if self._modal
        return _readyP.then ()->
          self._modal.show()
      hide: ()->
        self._modal?.hide()
        self._message = ''
      readyP: null
    }

    _readyP = $ionicModal.fromTemplateUrl 'views/partials/modal-console.html', {
        appConsole: self
        animation: 'slide-in-up'
      }
    .then (modal)->
        self._modal = modal
      , (error)->
        console.log "Error: $ionicModal.fromTemplate"
        console.log error

    return self
]
# borrowed from https://github.com/urish/angular-load/blob/master/angular-load.js
.service 'angularLoad', [
  '$document', '$q', '$timeout'
  ($document, $q, $timeout)->
    promises = {}
    this.loadScriptP = (src)->
      if !promises[src]
        dfd = $q.defer()
        script = $document[0].createElement('script');
        script.src = src
        element = script
        # event handlers onreadystatechange deprecatd for SCRIPT tags
        element.addEventListener 'load', (e)->
          return $timeout ()-> dfd.resolve(e)
        element.addEventListener 'error', (e)->
          return $timeout ()-> dfd.reject(e)
        promises[src] = dfd.promise
        $document[0].body.appendChild(element);
        # console.log "loadScriptP=", promises
      return promises[src]
    return
]