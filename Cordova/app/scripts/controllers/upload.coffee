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
  '$timeout', '$q', '$rootScope', '$ionicPlatform', 'otgData', 'otgParse', 'cameraRoll', '$cordovaNetwork', 'deviceReady', 'snappiMessengerPluginService'
  ($timeout, $q, $rootScope, $ionicPlatform, otgData, otgParse, cameraRoll, $cordovaNetwork, 
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

          #debug
          window.debug.up = self.uploader

        else # when "parse"
          self.uploader = _parseFileUploader
          self.type = self.uploader.type

      # CHECK if we are re-launching after bkg tasks scheduled
      _PROCESS_BKG_UPLOADS()
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

    _PROCESS_BKG_UPLOADS = ()->  
      return if !$rootScope.sessionUser
      switch self.uploader.type
        when 'parse'  
          return if !self.enable() || !self.connectionOK()
          if _parseFileUploader._photoFileQueue.length
            _parseFileUploader._uploadNextP()
          return
        when 'background'
          return PLUGIN.allSessionTaskInfosP()
          .then (resp)->
            if _.isEmpty resp
              console.log "\n >>> background upload tasks empty"
              return 
            finished = _.filter resp, (status)-> return !!status.hasFinished
            promises = []
            _.each finished, (status)->
              p = _bkgFileUploader.handleUploaderTaskFinishedP(status.asset)
              promises.push p
              return
            return $q.all(promises)

    $ionicPlatform.on 'pause' ,  ()->
      switch self.uploader.type
        when 'parse' 
          return 
        when 'background'
          return



    $ionicPlatform.on 'resume' ,  ()->
      _PROCESS_BKG_UPLOADS()
      


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

      queueP: (assetIds)->
        # entrypoint: called by otgWorkorderSync.queueDateRangeFilesP
        # queue immediately, 
        # but uploader must check isEnable before each upload
        # otgWorkorderSync.queueDateRangeFilesP(sync)
        #   promise = otgUploader.queueP( sync['addFile'])

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
      oneCompleteP: (resp)->
        self.callbacks.onEach(resp) if self.callbacks.onEach
        return resp
      oneError: (error)->
        self.callbacks.onError(error) if self.callbacks.onError
        return error
      allComplete: (o)->
        self.callbacks.onDone() if self.callbacks.onDone
        return o
      onNetworkAccessChanged: (allowsCellularAccess)->
        _parseFileUploader._uploadNextP() if _parseFileUploader.isEnabled && self.connectionOK()
        return  
      _uploadNextP: ()->
        # called by enable() and onNetworkAccessChanged()
        $timeout ()->
            UUID = _parseFileUploader._photoFileQueue.shift()
            if !UUID
              _parseFileUploader.allComplete()
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
              _parseFileUploader.oneCompleteP(resp)
              return resp
              _parseFileUploader._uploadNextP() if _parseFileUploader.isEnabled && self.connectionOK()
            .catch (error)->
              _parseFileUploader.oneError(error)
              return error
          , 10   
      _photoFileQueue : []
    }

    PLUGIN = snappiMessengerPluginService
    # call LastProgress.callback() after timeout, which is 'reset' after each call to restart()
    # used by oneProgress in case progress stops because network unavailable
    LastProgress = {
      callback: ()->return console.log "LastProgress Timeout" # override, fires when timer fires
      delay: 10000
      _timestamp: null
      _timer: null
      restart: ()->
        LastProgress._timestamp = new Date().getTime()
        return if LastProgress._timer?
        LastProgress._timer = $timeout ()->
          now = new Date().getTime()
          if ((now - LastProgress._timestamp) < LastProgress.delay )
            $timeout.cancel(LastProgress._timer)
            LastProgress._timer = null          # start a NEW timer
            LastProgress.restart()
          else 
            LastProgress.callback?()
          return 
        , LastProgress.delay 
      }

    _bkgFileUploader = { # uses snappiMessengerPluginService
      type: 'background' 
      isEnabled: false
      remaining: 0
      isPausingP: null
      cfg: 
        maxWidth: 720
        allowsCellularAccess: false
      use720p: (action=false)->
        _bkgFileUploader.cfg.maxWidth = 720 if action
        _bkgFileUploader.cfg.maxWidth = false if !action
        return action
      enable: (action)->
        return _bkgFileUploader.isEnabled if `action==null`
        wasEnabled = _bkgFileUploader.isEnabled
        _bkgFileUploader.isEnabled = 
          if action == 'toggle'
          then !_bkgFileUploader.isEnabled 
          else !!action
        return _bkgFileUploader.isEnabled if wasEnabled == _bkgFileUploader.isEnabled

        if _bkgFileUploader.isEnabled 
          console.log "\n>>> calling resumeQueueP from enable..."
          promise = _bkgFileUploader.isPausingP || $q.when()
          promise.then _bkgFileUploader.resumeQueueP
        else # disabled
          _bkgFileUploader.pauseQueueP()
        return _bkgFileUploader.isEnabled  

      queueP: (assetIds=[])->

        # entrypoint: called by otgWorkorderSync.queueDateRangeFilesP
        # called by enable() and onNetworkAccessChanged() > enable()
        # otgWorkorderSync.queueDateRangeFilesP(sync) OR _bkgFileUploader.enable(true)
        #   promise = otgUploader.queueP( sync['addFile'] )

        # add to _readyToSchedule queue, then schedule a chunk, as necessary
        if assetIds.length
          assetIds = _.filter assetIds, (UUID)->
            return false if _bkgFileUploader._complete[UUID] == 1
            return false if _bkgFileUploader._scheduled[UUID]?
            return true

          _bkgFileUploader._readyToSchedule = _.unique _bkgFileUploader._readyToSchedule.concat(assetIds)
          console.log "\n>>> queueP count=" + _bkgFileUploader.count()
          self.remaining( _bkgFileUploader.count() )

        scheduled = _.filter _bkgFileUploader._scheduled, (v,k)->
          return v != 1 
        return $q.when(_.keys scheduled) if scheduled.length > (_CHUNKSIZE/3)
        
        # schedule more from _bkgFileUploader._readyToSchedule
        assetIds = []
        while assetIds.length < _CHUNKSIZE && _bkgFileUploader._readyToSchedule.length > 0
          added = _bkgFileUploader._readyToSchedule.splice(0,_CHUNKSIZE)
          added = _.difference added, _.keys(_bkgFileUploader._scheduled)
          assetIds = assetIds.concat(added)

        return $q.when([]) if _.isEmpty assetIds  # all scheduled, but not all done

        _.defaults( _bkgFileUploader._scheduled, _.object(assetIds) )
          
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
          _pauseQueueP = ()->
            console.log "unscheduleAllAssetsP complete" + JSON.stringify resp
            # remainingScheduled at the front of the queue
            remainingScheduledAssetIds = _.reduce _bkgFileUploader._scheduled, (result, v,k)->
                return result if v == 1  # onProgress Done
                return result if _bkgFileUploader._complete[k]? # complete
                result.push k
                return result
              , []

            _bkgFileUploader._readyToSchedule = _.unique remainingScheduledAssetIds.concat( _bkgFileUploader._readyToSchedule ) 
            _bkgFileUploader._scheduled = {}
            _bkgFileUploader._complete = {}
            self.remaining( _bkgFileUploader.count() )
            _bkgFileUploader.isPausingP = null
            return

          dfd = $q.defer()
          $timeout ()->
              _pauseQueueP()
              return dfd.resolve()
            , 1000
          return _bkgFileUploader.isPausingP = dfd.promise

        
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
        _bkgFileUploader.oneCompleteP(resp)
        return resp

        

      oneProgress: (resp)->
        try
          progress = resp.totalBytesSent / resp.totalBytesExpectedToSend
          resp.progress = Math.round(progress*100)/100
          console.log "\n >>> native-uploader Progress: " + JSON.stringify _.pick resp, ['asset', 'progress'] 
          _bkgFileUploader._scheduled[resp.asset] = resp.progress
          LastProgress.restart()
        catch e
          # ...
        
      handleUploaderTaskFinishedP: (UUID)->
        return PLUGIN.sessionTaskInfoForIdentifierP(UUID)
          .then (status)->
              # status = { asset, progress, hasFinished, success, errorCode, url, name }
              return _bkgFileUploader.oneCompleteP(status)
            , (err)->
              console.log "\n\n %%% ERROR sessionTaskInfoForIdentifierP(): " + JSON.stringify err  
              $q.reject(err)
          .finally ()-> # or always()
              PLUGIN.removeSessionTaskInfoWithIdentifierP(UUID)

      oneCompleteP: (resp)->
        try
          # refactor: otgWorkorderSync.queueDateRangeFilesP() callbacks
          photo = {
            UUID: resp.asset
            src: if resp.success then resp.url else resp.message || 'error: native-uploader'
          }
          console.log "\n\n >>> oneCompleteP" + JSON.stringify resp

          return otgParse.updatePhotoP( photo, 'src')
          .then null, (err)->
            return $q.reject(err)
          .then (photos)-> # array of photoObj
            # update JS queue
            # remove from  _bkgFileUploader._scheduled and save on _complete

            _bkgFileUploader.queueP() # schedule more, as necessary

            ERROR_CANCELLED = -999
            if resp.success == false && resp.errorCode == ERROR_CANCELLED
              # add back to _readyToSchedule
              _bkgFileUploader._readyToSchedule.unshift( photo.UUID )
            else if resp.success == false
              _bkgFileUploader._complete[photo.UUID] = resp.errorCode  || resp.message # errorCode < 0
              _bkgFileUploader.oneError(resp)
            else 
              _bkgFileUploader._complete[photo.UUID] = 1
              self.callbacks.onEach(resp) if self.callbacks.onEach

            delete _bkgFileUploader._scheduled[photo.UUID] 
            remaining = self.remaining( _bkgFileUploader.count() )
            if remaining == 0
              $timeout( _bkgFileUploader.allComplete )
            console.log "onComplete: remaining files=" + remaining
            return photos
          .then null, (err)->
              console.warn "\n\noneCompleteP otgParse.updatePhotoP error"
              console.warn err
              _bkgFileUploader._complete[photo.UUID] = err.message || err
              _bkgFileUploader.oneError(err)
              return $q.reject(err)
        catch e
          return $q.reject(e)

      oneError: (error)->
        self.callbacks.onError(error) if self.callbacks.onError
        return error

      allComplete: (o)->
        return _bkgFileUploader.clearQueueP().then ()->
          self.callbacks.onDone() if self.callbacks.onDone
          return o


      onNetworkAccessChanged: (allowsCellularAccess)->
        PLUGIN.setAllowsCellularAccessP(allowsCellularAccess)
        .then (resp)->
            console.log "\n\n setAllowsCellularAccess() OK, set value=" + allowsCellularAccess
            console.log "_bkgFileUploader: scheduled tasks reset to allowsCellularAccess="+allowsCellularAccess
          , (err)->
            console.log "\n\n setAllowsCellularAccess() ERROR, set value=" + allowsCellularAccess
            console.log err 
        return

        # HACK: clear queue, then reschedule with updated value for allowsCellularAccess  
        # return _bkgFileUploader.clearQueueP()
        # .then (assetIds)->
        #   _bkgFileUploader._readyToSchedule = _.unique _bkgFileUploader._readyToSchedule.concat(assetIds)
        #   _bkgFileUploader.enable( _bkgFileUploader.isEnabled )

      _readyToSchedule: []    # array of assets on queue to be scheduled
      _scheduled:{} # hash of scheduled assets by UUID
      _complete:{}
      _registerBkgUploaderHandlers: ()->
        # TODO: confirm callbacks are set
        console.log "PLUGIN event handlers registered!!!"
        PLUGIN.on.didFinishAssetUpload (resp)->
          # expecting resp.asset
          return _bkgFileUploader.handleUploaderTaskFinishedP(resp.asset)

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
      callbacks:
        onEach: null
        onError: null
        onDone: null
      state :
        isActive : false
        isEnabled : null

      onLastProgressTimeout: (callback)->
        return if self.uploader.type != 'background'
        LastProgress.callback = callback 

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
  '$scope', '$rootScope', '$timeout', '$q', 'otgUploader', 'otgParse', 'deviceReady', 'otgWorkorderSync'
  ($scope, $rootScope, $timeout, $q, otgUploader, otgParse, deviceReady, otgWorkorderSync) ->
    $scope.label = {
      title: "Upload"
    }

    otgUploader.callbacks.onEach = (o)->
      $scope.on.fetchWarningsP()
      return o
    otgUploader.callbacks.onError = (o)->
      $scope.on.fetchWarningsP()
      return o
    otgUploader.callbacks.onDone = (o)->
      $scope.on.refresh()  
      return o




    $scope.otgUploader = otgUploader


    $scope.redButton = {
      press: (ev)-> 
        # toggle $scope['config']['upload']['enabled'] & $scope.$watch 'config.upload.enabled'
        target = angular.element(ev.currentTarget)
        target.addClass('down') # .activated is same as .enabled
        # console.log "press button"
        $scope.on.fetchWarningsP()
        .then (networkOK)->
          if otgUploader.enable('toggle')
            target.addClass('enabled') 
          else 
            target.removeClass('enabled') 
          return
      release: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.removeClass('down')
        return 

    }


    $scope.watch = {
      remaining: 0
      warnings: null
    }

    $scope.on = {
      refresh: ()->
        return $scope.SYNC_cameraRoll_Orders()  
      fetchWarningsP : ()->
        return deviceReady.waitP()
        .then ()->
          if otgUploader.isOffline()
            $scope.watch.warnings = i18n.tr('warning').offline
            networkOK = false
          else if otgUploader.isCellularNetwork() && !otgUploader.allowCellularNetwork()
            # TODO: remove this line when the native-uploader session checks for allowsCellularData
            otgUploader.uploader.pauseQueueP()  
            $scope.watch.warnings = i18n.tr('warning').cellular
            networkOK = false
          else   
            $scope.watch.warnings = null 
            networkOK = true  
          return $q.when(networkOK)  
    }




    $scope.$ionicPlatform.on 'offline', ()->
      $scope.on.fetchWarningsP()
    
    $scope.$ionicPlatform.on 'online', ()->  
      $scope.on.fetchWarningsP()

    $scope.$ionicPlatform.on 'resume' ,  ()-> 
      $scope.on.fetchWarningsP() 


    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      otgUploader.onLastProgressTimeout( $scope.on.fetchWarningsP )
      return if !$scope.deviceReady.isOnline()
      $scope.showLoading(true)      
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      $scope.on.fetchWarningsP()
      return if !$scope.deviceReady.isOnline()
      return $scope.DEBOUNCED_SYNC_cameraRoll_Orders()

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 

]
