'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:UploadCtrl
 # @description
 # # UploadCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.factory 'otgUploader', [
  '$timeout', '$q', '$rootScope', 'otgData', 'otgParse', 'cameraRoll', '$cordovaNetwork', 'deviceReady', 'snappiMessengerPluginService'
  ($timeout, $q, $rootScope, otgData, otgParse, cameraRoll, $cordovaNetwork, 
    deviceReady, snappiMessengerPluginService)->

    # ### private
    _CHUNKSIZE = 10 # set to $rootScope.config['upload']['CHUNKSIZE']
    # ###

    deviceReady.waitP().then ()->
      # UPLOADER_TYPE = [parse|background]
      # UPLOADER_TYPE = 'parse'
      UPLOADER_TYPE = 'background'

      UPLOADER_TYPE = 'parse' if deviceReady.isWebView()==false
      switch UPLOADER_TYPE
        when "background"
          self.uploader = _bkgFileUploader
          self.type = self.uploader.type
          self.uploader._registerBkgUploaderHandlers()

          self.uploader.getQueueP().then (assetIds)->
            self.remaining( assetIds.length)
            console.log "otgUploader init: remaining=" + _bkgFileUploader.remaining
          if self.uploader.enable()==false
            console.log "otgUploader init: PAUSE queue"
            self.uploader.pauseQueueP()

        else # when "parse"
          self.uploader = _parseFileUploader
          self.type = self.uploader.type
      return

    $rootScope.$watch 'config.upload', (newVal, oldVal)->
        if newVal['enabled'] != oldVal['enabled']  
          # console.log "otgUploader: enabled=" + newVal['enabled']
          self.uploader.enable( newVal['enabled'] )
        if newVal['use-720p-service'] != oldVal['use-720p-service']  
          console.log "otgUploader: use-720p-service=" + newVal['use-720p-service']
          self.uploader.use720p( newVal['use-720p-service'] )
        if newVal['use-cellular-data'] != oldVal['use-cellular-data']  
          console.log "otgUploader: use-cellular-data=" + newVal['use-cellular-data']
          self._allowCellularNetwork = newVal['use-cellular-data']
          self.uploader.onNetworkAccessChanged(newVal['use-cellular-data'])
        if newVal['auto-upload'] != oldVal['auto-upload'] 
          $rootScope.config['upload']['enabled'] = $rootScope.config['upload']['auto-upload'] 
        
        _CHUNKSIZE = newVal['CHUNKSIZE'] if newVal['CHUNKSIZE']

        return
      , true


    ### 
    syncDateRangePhotosP(dateRange).then
     resp = {
      new: [assetIds]     # in cameraRoll but NOT PhotoObj
      queued: [assetIds]  # PhotoObj.src == 'queued'
      errors: [assetIds]  # PhotoObj.src[0...5] == 'error' or 'Base6'
      complete: [assetIds] # complete
    }
    ###
    # photoUploads using parse. do not queue
    # fileUploads are queued, 

    
    _parseFileUploader = { # uses parse javascript API
      type: 'parse'
      isEnabled: false
      remaining: 0
      # isActive == isEnabled && remaining
      cfg:
        UPLOAD_IMAGE_SIZE: 'preview'
      use720p: (action=false)->
        _parseFileUploader.cfg.UPLOAD_IMAGE_SIZE = 'preview' if action
        _parseFileUploader.cfg.UPLOAD_IMAGE_SIZE = 'original' if !action
        return action
      enable: (action)->
        # onChange 'config.upload.auto-upload', set isEnabled = auto-upload
        return _parseFileUploader.isEnabled if `action==null`
        _parseFileUploader.isEnabled = 
          if action == 'toggle'
          then !_parseFileUploader.isEnabled 
          else !!action
        if _parseFileUploader.isEnabled && self.connectionOK()
          _parseFileUploader._uploadNextP()
        return _parseFileUploader.isEnabled          

      queueP: (assetIds, onEach, onErr, onDone)->
        # entrypoint: called by otgWorkorderSync.queueDateRangeFilesP
        # queue immediately, 
        # but uploader must check isEnable before each upload
        # otgWorkorderSync.queueDateRangeFilesP(sync)
        #   promise = otgUploader.queueP( sync['addFile'], onEach, onErr, onDone )

        # NOTE: queue tracks file uploads ONLY, photoMeta should already be on parse
        _parseFileUploader._photoFileQueue = _.unique _parseFileUploader._photoFileQueue.concat(assetIds)
        self.remaining( _parseFileUploader._photoFileQueue.length)
        if 'queue useDataURLs' 
          # preload DataURLs using cameraRoll.queue(), preloading is debounced
          _.each assetIds, (UUID)->
            cameraRoll.getDataURL UUID, _parseFileUploader.cfg.UPLOAD_IMAGE_SIZE
        if _parseFileUploader.isEnabled
          # same a RedButton.triggerHandler 'click'
          _parseFileUploader.enable( _parseFileUploader.isEnabled )
        return $q.when(_parseFileUploader._photoFileQueue)             
      getQueueP: ()->
        return $q.when _parseFileUploader._photoFileQueue
      pauseQueueP: ()->
        _parseFileUploader.enable(false)
      resumeQueueP: ()->
        _parseFileUploader.enable(true)
      clearQueueP: ()->
        cleared = _.clone _parseFileUploader._photoFileQueue
        _parseFileUploader._photoFileQueue = []
        return $q.when(cleared)
      oneComplete: ()->
      oneError: ()->
      allComplete: ()->
      onNetworkAccessChanged: (allowsCellularAccess)->
        _parseFileUploader._uploadNextP() if _parseFileUploader.isEnabled && self.connectionOK()
        return  
      _uploadNextP: ()->
        # called by enable() and onNetworkAccessChanged()
        $timeout ()->
            UUID = _parseFileUploader._photoFileQueue.shift()
            if !UUID
              _parseFileUploader.oneComplete()
              return
            otgParse.uploadPhotoFileP(UUID, _parseFileUploader.cfg.UPLOAD_IMAGE_SIZE) 
            .then (parseFile)->
              photo = {
                UUID: UUID
                src : parseFile.url()
              }
              return otgParse.updatePhotoP( photo, 'src')
            .then (resp)->
              console.log "_parseFileUploader update photo.src complete"
              self.remaining( _parseFileUploader._photoFileQueue.length)
              _parseFileUploader._uploadNextP() if _parseFileUploader.isEnabled && self.connectionOK()
          , 10   
      _photoFileQueue : []
    }

    PLUGIN = snappiMessengerPluginService
    _bkgFileUploader = { # uses snappiMessengerPluginService
      type: 'background' 
      isEnabled: false
      remaining: 0
      cfg: 
        maxWidth: 720
        allowsCellularAccess: false
      use720p: (action=false)->
        _bkgFileUploader.cfg.maxWidth = 720 if action
        _bkgFileUploader.cfg.maxWidth = false if !action
        return action
      enable: (action)->
        return _bkgFileUploader.isEnabled if `action==null`
        _bkgFileUploader.isEnabled = 
          if action == 'toggle'
          then !_bkgFileUploader.isEnabled 
          else !!action
        if _bkgFileUploader.isEnabled && self.connectionOK()
          console.log "\n>>> calling resumeQueueP from enable..."
          _bkgFileUploader.resumeQueueP()
        else # disabled
          _bkgFileUploader.pauseQueueP()
        return _bkgFileUploader.isEnabled  

      queueP: (assetIds=[], onEach, onErr, onDone)->

        # entrypoint: called by otgWorkorderSync.queueDateRangeFilesP
        # called by enable() and onNetworkAccessChanged() > enable()
        # otgWorkorderSync.queueDateRangeFilesP(sync) OR _bkgFileUploader.enable(true)
        #   promise = otgUploader.queueP( sync['addFile'], onEach, onErr, onDone )

        # add to _readyToSchedule queue, then schedule a chunk
        if assetIds.length
          assetIds = _.filter assetIds, (UUID)->
            return false if _bkgFileUploader._complete[UUID] == 1
            return false if _bkgFileUploader._scheduled[UUID]?
            return true

          _bkgFileUploader._readyToSchedule = _.unique _bkgFileUploader._readyToSchedule.concat(assetIds)
          console.log "\n>>> queueP count=" + _bkgFileUploader.count()
          self.remaining( _bkgFileUploader.count() )

        if _bkgFileUploader.isEnabled == false
          console.log "_bkgFileUploader disabled: do NOT queue"
          self.remaining( _bkgFileUploader.count()  )
          return $q.when(_bkgFileUploader._readyToSchedule) 

        
        assetIds = _bkgFileUploader._readyToSchedule.splice(0,_CHUNKSIZE)  
        if _.isEmpty assetIds
          # all done!
          return self.clearQueueP().then ()->
            console.log "\n\n >>> otgUploader background upload queue is empty. DONE"
            self.remaining( _bkgFileUploader.count() )
            onDone() if onDone
            return assetIds


        _.defaults( _bkgFileUploader._scheduled, _.object(assetIds) )
        return $q.when() if assetIds.length == 0
          
        # enabled
        options = _.pick _bkgFileUploader.cfg, ['allowsCellularAccess', 'maxWidth', 'auto-rotate']  
        return PLUGIN.scheduleAssetsForUploadP(assetIds, options).then ()->
          console.log "\n>>> otgUploader.queueP(): scheduleAssetsForUploadP complete\n\n"
          return _.keys _bkgFileUploader._scheduled
        .catch (err)->
          console.warn "\n >>> ERROR PLUGIN.scheduleAssetsForUploadP() " + JSON.stringify err

      getQueueP: ()->
        return $q.when( _bkgFileUploader._readyToSchedule ) if _bkgFileUploader.isEnabled == false
        return $q.when _.keys( _bkgFileUploader._scheduled ).concat( _bkgFileUploader._readyToSchedule )
        
      count: ()->
        return _.keys( _bkgFileUploader._scheduled ).length +  _bkgFileUploader._readyToSchedule.length

      pauseQueueP: ()->
        return PLUGIN.unscheduleAllAssetsP().then (resp)->
          console.log "unscheduleAllAssetsP complete" + JSON.stringify resp
          # remainingScheduled at the front of the queue
          remainingScheduledAssetIds = _.reduce _bkgFileUploader._scheduled, (result, v,k)->
              return result if v==1  # onProgress Done
              return result if _bkgFileUploader._complete[k]? # complete
              result.push k
              return result
            , []
          _bkgFileUploader._readyToSchedule = _.unique remainingScheduledAssetIds.concat( _bkgFileUploader._readyToSchedule ) 

          _bkgFileUploader._scheduled = {}
          self.remaining( _bkgFileUploader.count() )
        
      resumeQueueP: ()->
        # just queue a chunk from _bkgFileUploader._readyToSchedule
        return _bkgFileUploader.queueP().then (scheduledAssetIds)->
          console.log "\n>>> queueP complete from resumeQueueP()"
          console.log scheduledAssetIds

      clearQueueP: ()->
        return PLUGIN.unscheduleAllAssetsP().then ()->
          _bkgFileUploader._scheduled = {}
          _bkgFileUploader._complete = {}
          _bkgFileUploader._readyToSchedule = []
          return 

      oneBegan: (resp)->
        try
          console.log "\n >>> native-uploader Began: for assetId="+resp.asset
          _bkgFileUploader._scheduled[resp.asset] = 0
        catch e
          # ...
        
      oneScheduleError : (resp)->
        # resp.asset
        # resp.errorCode
        resp['success'] = false
        resp['message'] = 'error: failed to schedule'
        return self.oneComplete(resp)

        

      oneProgress: (resp)->
        try
          progress = resp.totalBytesSent / resp.totalBytesExpectedToSend
          resp.progress = Math.round(progress*100)/100
          console.log "\n >>> native-uploader Progress: " + JSON.stringify _.pick resp, ['asset', 'progress'] 
          _bkgFileUploader._scheduled[resp.asset] = resp.progress
        catch e
          # ...
        

      oneComplete: (resp, onEach)->
        try
          # refactor: otgWorkorderSync.queueDateRangeFilesP() callbacks
          photo = {
            UUID: resp.asset
            src: if resp.success then resp.url else resp.message || 'error: native-uploader'
          }
          console.log "\n\n >>> oneComplete" + JSON.stringify resp

          return otgParse.updatePhotoP( photo, 'src')
          .then (photoObj)->
            # update JS queue
            # remove from  _bkgFileUploader._scheduled and save on _complete

            if _.keys( _bkgFileUploader._scheduled).length < 3
              # schedule another chunk
              promise = _bkgFileUploader.queueP()

            ERROR_CANCELLED = -999
            if !resp.success && resp.errorCode == ERROR_CANCELLED
              # add back to _readyToSchedule
              _bkgFileUploader._readyToSchedule.unshift( photo.UUID )
            else if resp.success == false
              _bkgFileUploader.complete[photo.UUID] = resp.errorCode  || resp.message # errorCode < 0
              onError(resp) if onError
            else 
              _bkgFileUploader._complete[photo.UUID] = 1
              onEach(resp) if onEach


            delete _bkgFileUploader._scheduled[photo.UUID] 
            remaining = self.remaining( _bkgFileUploader.count() )
            console.log "onComplete: remaining files=" + remaining
            return photoObj
          .then null, (err)->
              console.warn "\n\noneComplete otgParse.updatePhotoP error"
              console warn err
              _bkgFileUploader.complete[photo.UUID] = err.message || err
              return $q.reject(err)
        catch e
          # ...

      oneError: ()->
      allComplete: ()->


      onNetworkAccessChanged: (allowsCellularAccess)->
        PLUGIN?.setAllowsCellularAccessP(allowsCellularAccess).then ()->
          console.log "_bkgFileUploader: scheduled tasks reset to allowsCellularAccess="+allowsCellularAccess
        # HACK: clear queue, then reschedule with updated value for allowsCellularAccess  
        return _bkgFileUploader.clearQueueP()
        .then (assetIds)->
          _bkgFileUploader._readyToSchedule = _.unique _bkgFileUploader._readyToSchedule.concat(assetIds)
          _bkgFileUploader.enable( _bkgFileUploader.isEnabled )

      _readyToSchedule: []    # array of assets on queue to be scheduled
      _scheduled:{} # hash of scheduled assets by UUID
      _complete:{}
      _registerBkgUploaderHandlers: ()->
        # TODO: confirm callbacks are set
        console.log "PLUGIN event handlers registered!!!"
        PLUGIN.on.didFinishAssetUpload (resp)->
          return _bkgFileUploader.oneComplete(resp)

        PLUGIN.on.didUploadAssetProgress (resp)->
          return _bkgFileUploader.oneProgress(resp)      

        PLUGIN.on.didBeginAssetUpload (resp)->
          return _bkgFileUploader.oneBegan(resp)

        PLUGIN.on.didFailToScheduleAsset (resp)->
          return _bkgFileUploader.oneScheduleError(resp)

        return
            
    }


    self = {
      _allowCellularNetwork: false
      _queue : []
      UPLOAD_IMAGE_SIZE: 'preview'
      state :
        isActive : false
        isEnabled : null

      ### states & classes
        $scope['config']['upload']['enabled'] => self.uploader.isEnabled 
          NOTE: isEnabled and remaining states do not conflict
          # UX play/pause to match state
          .enabled.queued (green cloud): uploader.isEnabled && uploader.remaining
          .enabled (green cloud): uploader.isEnabled && !uploader.remaining
          .queued (yellow pause): !uploader.isEnabled && uploader.remaining
          :not(.enabled) (white cloud): !uploader.isEnabled && !uploader.remaining
      ###

      enable : (action)-> 
        return $rootScope['config']['upload']['enabled'] if `action==null`
        isEnabled = 
          if action == 'toggle'
          then !self.uploader.enable()
          else !!action
        return $rootScope['config']['upload']['enabled'] = isEnabled
      remaining: (value)->
        return self.uploader.remaining if `value==null`
        self.uploader.remaining = value
        $rootScope.counts.uploaderRemaining = value
        return value

      isActive: ()->
        return self.uploader.isEnabled && self.uploader.remaining  

      isOffline: ()->
        return false if !deviceReady.isWebView()
        return $cordovaNetwork.isOffline()

      allowCellularNetwork: (value)->
        self._allowCellularNetwork = value if `value!=null`
        return self._allowCellularNetwork

      isCellularNetwork: ()->
        return false if !deviceReady.isWebView()
        type = $cordovaNetwork.getNetwork()
        isCellular = [Connection.CELL, Connection.CELL_2G, Connection.CELL_3G, Connection.CELL_4G].indexOf(type) > -1
        return isCellular

      connectionOK: ()->
        return true if !deviceReady.isWebView()
        if $cordovaNetwork.isOffline()
          return false
        if self.isCellularNetwork() && !self.allowCellularNetwork()
          return false
        return true 


    }

    return self
]
.controller 'UploadCtrl', [
  '$scope', '$rootScope', '$timeout',  'otgUploader', 'otgParse', 'deviceReady', 'otgWorkorderSync'
  ($scope, $rootScope, $timeout, otgUploader, otgParse, deviceReady, otgWorkorderSync) ->
    $scope.label = {
      title: "Upload"
    }


    $scope.otgUploader = otgUploader

    $scope.redButton = {
      press: (ev)-> 
        # toggle $scope['config']['upload']['enabled'] & $scope.$watch 'config.upload.enabled'
        target = angular.element(ev.currentTarget)
        target.addClass('down') # .activated is same as .enabled
        # console.log "press button"
        if otgUploader.enable('toggle')
          target.addClass('enabled') 
        else 
          target.removeClass('enabled') 
        _fetchWarnings()
        return
      release: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.removeClass('down')
        return 

    }

    # can't change value within controller
    # $scope.$watch 'config.upload.use-cellular-data', (newVal, oldVal)->
    #   return if newVal == oldVal
    #   otgUploader.allowCellularNetwork(newVal)
    #   return
    $scope.warnings = null
    _fetchWarnings = ()->
      return deviceReady.waitP()
      .then ()->
        if otgUploader.isOffline()
          return $scope.warnings = i18n.tr('warning').offline
        if otgUploader.isCellularNetwork() && !otgUploader.allowCellularNetwork()
          return $scope.warnings = i18n.tr('warning').cellular
        return $scope.warnings = null


    $scope.watch = {
      remaining: 0
    }
    $scope.on = {
      refresh: ()->
        return $scope.SYNC_cameraRoll_Orders()       
    }


    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      _fetchWarnings()

      _force = !otgWorkorderSync._workorderColl['owner'].length
      return if !_force 
      return if !$scope.deviceReady.isOnline()
      return $scope.DEBOUNCED_SYNC_cameraRoll_Orders()

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 

]
