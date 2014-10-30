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
  '$timeout', 'otgData', 'otgParse'
  ($timeout, otgData, otgParse)->

    self = {
      _queue : []
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
      startUploading: (count=0, photos)->
        if count && _.isNumber(count)
          self._queue.push(photos[i]) for i in [0..count] 
        if self.state.isEnabled && self._queue.length
          self.state.isActive = true if count!='toggle'
          $timeout ()->
              index = self._queue.length




              photo = self._queue.shift()
              # test upload to parse
              otgParse.uploadPhotoP(photo)


              self.state.isActive = !self.state.isActive && self._queue.length
              self.startUploading('toggle') 
            , 500
        else if !self.state.isEnabled || self._queue.length
          self.state.isActive = false


      isQueued: ()->
        return !!self.queueLength() 
      queueLength: ()->
        return self._queue?.length || 0
      queue: (momentsOrPhotos)->
        throw "ERROR: expecting an array of moments or photos" if !_.isArray(momentsOrPhotos)
        if momentsOrPhotos[0]?.type == 'moment' 
          photos = otgData.parsePhotosFromMoments momentsOrPhotos
        else if momentsOrPhotos[0]?.id?
          photos = momentsOrPhotos
        else if _.isString(momentsOrPhotos[0])
          photos = momentsOrPhotos

        _.each photos, (photo)->

          self._queue.push photo.id
        return


    }

    return self
]
.controller 'UploadCtrl', [
  '$scope', '$timeout',  'otgUploader'
  ($scope, $timeout, otgUploader) ->
    $scope.label = {
      title: "Upload"
    }

    $scope.otgUploader = otgUploader

    $scope.redButton = {
      press: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.addClass('activated')
        if otgUploader.enable('toggle')
          target.addClass('enabled') 
          otgUploader.startUploading()
        else 
          target.removeClass('enabled') 
        return
      release: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.removeClass('activated')
        target.removeClass('enabled') if otgUploader.enable()
        # $timeout ()->
        #     target.removeClass('activated')
        #     target.removeClass('enabled') if otgUploader.enable()
        #   , 100
        return  
      demo: (ev)->
        otgUploader.enable(true)
        otgUploader.startUploading(2, $scope.cameraRoll_DATA.photos)

    }

    init =()->
      if otgUploader.enable()==null
        otgUploader.enable($scope.config.upload['auto-upload'])

    init() 

]
