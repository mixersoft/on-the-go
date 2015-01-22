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
  '$timeout', '$q', 'otgData', 'otgParse', 'cameraRoll', '$cordovaNetwork', 'deviceReady', 'snappiMessengerPluginService'
  ($timeout, $q, otgData, otgParse, cameraRoll, $cordovaNetwork, deviceReady, snappiMessengerPluginService)->

    self = {
      _allowCellularNetwork: false
      _queue : []
      UPLOAD_IMAGE_SIZE: 'preview'
      state :
        isActive : false
        isEnabled : null
      enable : (action=null)->
        if action=='toggle'
          this.state.isEnabled = !this.state.isEnabled 
          self.backgroundQueue(this.state.isEnabled) 
        else if action!=null
          this.state.isEnabled =  !!action
          self.backgroundQueue(this.state.isEnabled) 
        else 
          this.state.isEnabled # just get current value
        return this.state.isEnabled
      backgroundQueue : (action)->
        # called by $watch 'config.upload.enabled'
        if action
          console.log "TODO: scheduleAssetsForUploadP"
        else 
          console.log "TODO: unscheduleAssetsForuploadP"

      isActive: ()->
        return self.state.isActive  

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

      startNativeFileUploadingP: ()->
        # we only want to get imageWidth/Height for nativeFileUploading
        self.UPLOAD_IMAGE_SIZE = 'thumbnail' 

        # add photoObj to Parse with src='queued'
        # WARNING: will not be able to queue photoMeta in airplane mode, 
        # but that should not affect queue count
        promises = []
        _.each self._queue, (item)->
          return if /queued|complete/.test(item.photo?.status)
          workorderObj = item.workorderObj
          photo = item.photo

          # find the photo, if we have it
          found = cameraRoll.getPhoto(photo.UUID)
          $q.when(found)
          .then (found)->
            if !found
              return cameraRoll.getDataURL_P( UUID, self.UPLOAD_IMAGE_SIZE) 
            return found
          .then (found)->
            if !found 
              return $q.reject("ERROR: startNativeFileUploadingP() UUID not found in cameraRoll. deleted?")
            p = otgParse.uploadPhotoMetaP(workorderObj, found).then ()->
                  item.photo.status = "queued"
                  return
                , (err)->
                  item.photos.status = 'error: photo meta'
                  return
            promises.push p 
            return p
 

        $q.all(promises)
        .then (o)->
          console.log "*** startNativeFileUploadingP.uploadPhotoMetaP() complete. count=" + _.values(o).length


        # TODO: need to change method for counting queued uploads
        return

      uploadPhotoFileComplete : (resp)->
        # handler for nativeFileUploader
        # resp:
          # asset:{string phasset id}, 
          # name:{string (Parse name)}    # Parse URL
          # success: bool
        console.log "***** uploadPhotoFileComplete called!!!"

        # find queue item
        queuedPhotos = _.pluck otgUploader._queue, 'photo'
        queuedPhoto = _.find queuedPhotos, {UUID: resp.asset}

        if resp.success == false
          status = queuedPhoto.src = 'error: file upload'
        else 
          status = 'complete'
          queuedPhoto.src = resp.name

        otgParse.updatePhotoP(queuedPhoto, 'src') # update Parse
        .then ()->
            return queuedPhoto.status = 'complete'
          , (err)->
            return queuedPhoto.status = 'error: update Photo.src' 

      startUploadingP: (onProgress)->

        return if !self.connectionOK()

        if self.state.isEnabled && self._queue.length
          item = self._queue.shift()
          workorderObj = item.workorderObj
          photo = item.photo

          # find the photo, if we have it
          found = cameraRoll.getPhoto( photo?.UUID || photo )
          if !found
            console.error '\n\nERROR: queued photo is not found, UUID=' + photo.UUID || photo
            return $q.when() 

          console.log "\n\nuploadQueue will upload photo="+JSON.stringify photo


          # test upload to parse
          self.state.isActive = true

          otgParse.uploadPhotoP( workorderObj, photo).then ()->
              self.state.isActive = false
              workorderObj.increment('count_received')

              return workorderObj.save()

            , (error)->
              # check for duplicate assetId using cloud code
              # https://www.parse.com/questions/unique-fields--2
              if error == "Duplicate Photo.assetId Detected"
                workorderObj.increment('count_received')
                workorderObj.increment('count_duplicate')
                return workorderObj.save()
              else 
                return $q.when()
            .then ()->
              onProgress() if onProgress
              return self.startUploadingP()  if self._queue.length # repeat recursively
              return $q.when() # finish


        else if !self.state.isEnabled || self._queue.length
          self.state.isActive = false
        return $q.when()

      isQueued: ()->
        return !!self.queueLength() 
      queueLength: ()->
        return self._queue?.length || 0
      ## @param photos array of photo Objects or UUIDs  

      XXXqueueP: (workorderObj, photos)->
        # DEPRECATE, not async
        self.queue(workorderObj, photos)
        return $q.when(self._queue)

      queue: (workorderObj, photos, force=true)->
        return self._queue if _.isEmpty(photos) && !force
        # queued photos will be preloaded, do NOT upload until complete
        queuedPhotos = _.pluck self._queue, 'photo'
        dictQueuedPhotos = _.indexBy queuedPhotos, 'UUID'

        # queuedPhotos = _ .reduce self._queue, (result, item)->
        #     result.push item.photo if _.isString item.photo
        #     result.push item.photo.UUID if item.photo.UUID
        #     return result
        #   , []

        
        addedToQueue = _.reduce photos, (assetIds, photo)->
            queued = dictQueuedPhotos[photo.UUID]
            if queued   #re-queue errors
              queued.status = null 
              return assetIds
            item = {
              photo: photo
              workorderObj: workorderObj
            }
            self._queue.push item
            # preload DataURLs using cameraRoll.queue(), preloading is debounced
            cameraRoll.getDataURL photo.UUID, self.UPLOAD_IMAGE_SIZE
            assetIds.push photo.UUID
            return assetIds
          , []
        if force && !_.isEmpty(dictQueuedPhotos)
          addedToQueue.concat(dictQueuedPhotos)

        return self._queue if _.isEmpty addedToQueue
        return self._queue if $scope.config.upload.enabled == false

        data = {
          assets: addedToQueue
          options:
            targetWidth: 640
            targetHeight: 640
            resizeMode: 'aspectFit'
            autoRotate: true            
        }
        snappiMessengerPluginService.scheduleAssetsForUploadP(data)
        .then (resp)->
            console.log "*** upload: snappiMessengerPluginService.scheduleAssetsForUploadP, queue length="+addedToQueue.length
            console.log resp 
            return 
          , (error)->
            console.log "*** ERROR: snappiMessengerPluginService.scheduleAssetsForUploadP"
            console.log error

        return self._queue

      clear : ()->
        self._queue = []
        return self._queue.length

    }

    return self
]
.controller 'UploadCtrl', [
  '$scope', '$timeout',  'otgUploader', 'otgParse', 'deviceReady', 'snappiMessengerPluginService'
  ($scope, $timeout, otgUploader, otgParse, deviceReady, snappiMessengerPluginService) ->
    $scope.label = {
      title: "Upload"
    }

    onProgress = ()->
      $scope.menu.uploader.count = otgUploader.queueLength()

    $scope.otgUploader = otgUploader

    $scope.redButton = {
      press: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.addClass('activated')
        if otgUploader.enable('toggle')
          target.addClass('enabled') 
          # upload photo meta
          otgUploader.startNativeFileUploadingP(onProgress) 
        else 
          target.removeClass('enabled') 
        $scope['config']['upload']['enabled'] = otgUploader.enable()  
        _fetchWarnings()
        return
      release: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.removeClass('activated')
        if !otgUploader.enable()
          target.removeClass('enabled') 
        
        $scope.menu.uploader.count = otgUploader.queueLength()
        $scope['config']['upload']['enabled'] = otgUploader.enable()
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


    $scope.$on '$ionicView.loaded', ()->
      otgUploader.enable( $scope['config']['upload']['enabled'] )

      # once per controller load, setup code for view
      # # register handlers for native uploader
      # snappiMessengerPluginService.on.didFinishAssetUpload(otgUploader.uploadPhotoFileComplete)
      # console.log '\n\n ***** upload: handler registered for didFinishAssetUpload'
      # # update queue, count
      # console.log otgUploader.uploadPhotoFileComplete

      # snappiMessengerPluginService.on.didBeginAssetUpload (resp)->
      #     console.log "\n\n ***** didBeginAssetUpload"
      #     console.log resp
      #     return
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      otgUploader.allowCellularNetwork($scope.config.upload['use-cellular-data'])
      $scope.menu.uploader.count = otgUploader.queueLength()
      if otgUploader.enable()==null
        otgUploader.enable($scope.config.upload['auto-upload'])

      _fetchWarnings()
      return

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 




]
