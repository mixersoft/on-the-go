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
  '$timeout', '$q', 'otgData', 'otgParse', 'cameraRoll', 'snappiMessengerPluginService'
  ($timeout, $q, otgData, otgParse, cameraRoll, snappiMessengerPluginService)->

    self = {
      _queue : []
      _workorder: null
      UPLOAD_IMAGE_SIZE: 'preview'
      state :
        isActive : false
        isEnabled : null
      enable : (action=null)->
        if action=='toggle'
          return this.state.isEnabled = !this.state.isEnabled 
        else if action!=null
          return this.state.isEnabled =  !!action
        else 
          return this.state.isEnabled
      isActive: ()->
        return self.state.isActive    
      startUploadingP: (onProgress)->

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

      XXXqueueP: (workorderObj, photos)->
        # DEPRECATE, not async
        self.queue(workorderObj, photos)
        return $q.when(self._queue)

      queue: (workorderObj, photos)->
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

    }

    return self
]
.controller 'UploadCtrl', [
  '$scope', '$timeout',  'otgUploader', 'otgParse'
  ($scope, $timeout, otgUploader, otgParse) ->
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
          otgUploader.startUploadingP(onProgress)
        else 
          target.removeClass('enabled') 
        
        return
      release: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.removeClass('activated')
        target.removeClass('enabled') if otgUploader.enable()
        
        $scope.menu.uploader.count = otgUploader.queueLength()
        return 

    }

    init =()->
      $scope.menu.uploader.count = otgUploader.queueLength()
      if otgUploader.enable()==null
        otgUploader.enable($scope.config.upload['auto-upload'])

    init() 

]
