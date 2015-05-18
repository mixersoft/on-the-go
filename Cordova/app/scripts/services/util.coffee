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
          if $localStorage['device']?.id?
            _device = angular.copy $localStorage['device']
            return deferred.resolve( _device )

          platform = _.defaults ionic.Platform.device(), {
            available: false
            cordova: false
            platform: 'browser'
            uuid: 'browser'
            id: 'browser'
          }
          $localStorage['device'] = {} 
          _.extend $localStorage['device'],
           {
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

.filter 'timeago', [
  ()->
    return (time, local, raw)->
      return '' if !time

      time = new Date(time) if _.isString time
      time = time.getTime() if _.isDate time

      local = Date.now() if `local==null`
      local = local.getTime() if _.isDate local

      return '' if !_.isNumber(time) || !_.isNumber(local) 

      offset = Math.abs((local - time) / 1000)
      span = []
      MINUTE = 60
      HOUR = 3600
      DAY = 86400
      WEEK = 604800
      MONTH = 2629744
      YEAR = 31556926
      DECADE = 315569260

      timeSpan = {
        'days ': Math.floor( offset/DAY )
        'h': Math.floor( (offset % DAY)/HOUR )
        'm': Math.floor( (offset % HOUR)/MINUTE )
        # 's': timeSpan.push Math.floor( (offset % MINUTE) )
      }
      timeSpan = _.reduce timeSpan, (result, v,k)->
          result += v+k if v
          return result
        , ""
      return if time <= local then timeSpan + ' ago' else 'in ' + timeSpan


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
# notify DOM element to show a notification message in app with 
# timeout and close
# TODO: make a controller for directive:notify
.service 'notifyService', [
  '$timeout', '$rootScope'
  ($timeout, $rootScope, $compile)->
    CFG = {
      debug: true
      timeout: 5000 
      messageTimeout: 5000  
    }
    ###
    template:
      <div id="notify" class="notify overlay">
          <alert ng-repeat="alert in notify.alert()" 
          type="alert.type" 
          close="notify.close(alert.key)"
          ><div ng-bind-html="alert.msg"></div></alert>
        </div>
        <div id="message" class="notify inline">
          <alert ng-repeat="alert in notify.message()" 
          type="alert.type" 
          close="notify.close(alert.key)"
          >
            <div ng-if="!alert.template" ng-bind-html="alert.msg"></div>
            <ng-include ng-if="alert.template" src="alert.template || null"></ng-include>
          </alert>
        </div>      
    ###
    this._cfg = CFG
    this.alerts = {}
    this.messages = {}
    this.timeouts = []

    this.alert = (msg=null, type='info', timeout)->
      return this.alerts if !CFG.debug || CFG.debug=='off'
      if msg? 
        timeout = timeout || CFG.timeout
        now = new Date().getTime()
        `while (this.alerts[now]) {
          now += 0.1;
        }`
        this.alerts[now] = {msg: msg, type:type, key:now} if msg?
        this.timeouts.push({key: now, value: timeout})
      else 
        # start timeouts on ng-repeat
        this.timerStart()
      return this.alerts
    # same as alert, but always show, ignore CFG.debug  
    this.message = (msg=null, type='info', timeout)->
      if msg? 
        timeout = timeout || CFG.messageTimeout
        now = new Date().getTime()
        `while (this.alerts[now]) {
          now += 0.1;
        }`
        notification = {type:type, key:now} 
        if _.isObject(msg)
          if msg.template?
            notification['template'] = msg.template
          else if msg.title?
            notification['msg'] = "<h4>"+msg.title+"</h4><p>"+msg.message+"</p>"
          else 
            notification['msg'] = msg.message
        else 
          notification['msg'] = msg

        this.messages[now] = notification
        this.timeouts.push({key: now, value: timeout})

        $rootScope.$apply() if !$rootScope.$$phase
      else 
        # start timeouts on ng-repeat
        this.timerStart()
      return this.messages
    this.clearMessages = ()->
      this.messages = {}
    this.close = (key)->
      delete this.alerts[key] if this.alerts[key]
      delete this.messages[key] if this.messages[key]
    this.timerStart = ()->
      _.each this.timeouts, (o)=>
        $timeout (()=>
          delete this.alerts[o.key] if this.alerts[o.key]
          delete this.messages[o.key] if this.messages[o.key]
        ), o.value
      this.timeouts = []
    return  
]