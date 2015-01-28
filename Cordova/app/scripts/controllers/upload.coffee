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
  ($timeout, $q, $rootScope, otgData, otgParse, cameraRoll, $cordovaNetwork, deviceReady, snappiMessengerPluginService)->

    $rootScope.$watch 'config.upload', (newVal, oldVal)->
        if newVal['enabled'] != oldVal['enabled']  
          console.log "otgUploader: enabled=" + newVal['enabled']
          self.enableBackgroundQueueP newVal['enabled'] 
        return
      , true


    

    self = {
      _allowCellularNetwork: false
      _queue : []
      UPLOAD_IMAGE_SIZE: 'preview'
      state :
        isActive : false
        isEnabled : null

      ### states:
        $scope['config']['upload']['enabled'] => self.enabled , .enabled => resume/suspend nativeUploader
          can be .enabled with empty queue
      ###

      enable : (action)->
        return this.state.isEnabled if `action==null`
        # this.state.isEnabled = $rootScope.config.upload.enabled
        if action == 'toggle'
          this.state.isEnabled = !this.state.isEnabled 
        else 
          this.state.isEnabled =  !!action
        return $rootScope['config']['upload']['enabled'] = this.state.isEnabled
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

      startUploadingP: (onProgress)->

        return if !self.connectionOK()

        if self.state.isEnabled && self._queue.length
          item = self._queue.shift()
          workorderObj = item.workorderObj
          photo = item.photo

          # find the photo, if we have it
          found = _.find cameraRoll.photos, {UUID: photo.UUID || photo } 
          # get from cameraRoll.map() if not in cameraRoll.photo
          found = _.find cameraRoll.map(), {UUID: photo.UUID || photo } if !found
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

      queue1: (workorderObj, photos)->
        # need to queue photo by UUID because it might not be loaded from cameraRoll
        alreadyQueued = _ .reduce self._queue, (result, item)->
            result.push item.photo if _.isString item.photo
            result.push item.photo.UUID if item.photo.UUID
            return result
          , []

        _.each photos, (photoOrUUID)->
          UUID = if photoOrUUID.UUID then photoOrUUID.UUID else photoOrUUID
          return if alreadyQueued.indexOf( UUID ) > -1
          item = {
            photo: photoOrUUID
            workorderObj: workorderObj
          }
          self._queue.push item
          
          # preload DataURLs using cameraRoll.queue(), preloading is debounced
          cameraRoll.getDataURL UUID, self.UPLOAD_IMAGE_SIZE
          return
        
        return self._queue

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
            if 'useDataURLs' && false
              # preload DataURLs using cameraRoll.queue(), preloading is debounced
              cameraRoll.getDataURL photo.UUID, self.UPLOAD_IMAGE_SIZE
            assetIds.push photo.UUID
            return assetIds

      clear : ()->
        self._queue = []
        return self._queue.length

    }

    return self
]
.controller 'UploadCtrl', [
  '$scope', '$timeout',  'otgUploader', 'otgParse', 'deviceReady'
  ($scope, $timeout, otgUploader, otgParse, deviceReady) ->
    $scope.label = {
      title: "Upload"
    }

    onProgress = ()->
      $scope.menu.uploader.count = otgUploader.queueLength()

    $scope.otgUploader = otgUploader

    # ???: what is the event to update counter?
    # $rootScope.$broadcast 'queue-changed', {remaining: int}
    $scope.$on 'queue-changed', (newVal, oldVal)->
      $scope.menu.uploader.count = otgUploader.queueLength()
      return

    $scope.redButton = {
      press: (ev)-> 
        # toggle $scope['config']['upload']['enabled'] & $scope.$watch 'config.upload.enabled'
        target = angular.element(ev.currentTarget)
        target.addClass('down') # .activated is same as .enabled
        if otgUploader.enable('toggle')
          target.addClass('enabled') 
        else 
          target.removeClass('enabled') 
        $scope.menu.uploader.count = otgUploader.queueLength()
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


    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
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
