'use strict'

###*
 # @ngdoc service
 # @name ionBlankApp.util
 # @description
 # # utility services
###


angular.module 'snappi.util', []
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