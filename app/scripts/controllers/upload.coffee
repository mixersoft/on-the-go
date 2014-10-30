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
  '$timeout', '$q', 'otgData', 'otgParse',
  ($timeout, $q, otgData, otgParse)->

    self = {
      _lastUpload: 0  # just for testing purposes
      _queue : []
      _workorder: null
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
      startUploadingP: (workorder, count=0, photos)->
        if count && _.isNumber(count)
          end = self._lastUpload + count
          self._queue.push(photos[i]) for i in [self._lastUpload..end]
          self._lastUpload = end
          self._workorder = workorder

        if self.state.isEnabled && self._queue.length
          self.state.isActive = true if count!='toggle'
          index = self._queue.length

          photo = self._queue.shift()
          # test upload to parse
          self.state.isActive = true
          otgParse.uploadPhotoP(self._workorder, photo).then ()->
              self.state.isActive = false
              self._workorder.increment('count_received')
              return self._workorder.save()
            , (error)->
              # check for duplicate assetId using cloud code
              # https://www.parse.com/questions/unique-fields--2
              if error == "Duplicate Photo.assetId Detected"
                self._workorder.increment('count_received')
                self._workorder.increment('count_duplicate')
                return self._workorder.save()
              else 
                return $q.when()
            .then ()->
              return self.startUploadingP()  if self._queue.length # repeat recursively
              return $q.when() # finish


        else if !self.state.isEnabled || self._queue.length
          self.state.isActive = false
        return $q.when()

      isQueued: ()->
        return !!self.queueLength() 
      queueLength: ()->
        return self._queue?.length || 0
      queueP: (workorder, photos)->
        self._workorder = workorder
        _.each photos, (photo)->
          self._queue.push photo
        return $q.when(self._queue)

    }

    return self
]
.controller 'UploadCtrl', [
  '$scope', '$timeout',  'otgUploader', 'otgParse'
  ($scope, $timeout, otgUploader, otgParse) ->
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
          otgUploader.startUploadingP()
        else 
          target.removeClass('enabled') 
        return
      release: (ev)-> 
        target = angular.element(ev.currentTarget)
        target.removeClass('activated')
        target.removeClass('enabled') if otgUploader.enable()
        return 


      # deprecate: use checkout instead   
      demo: (ev)->
        return 
        otgUploader.enable(true)
        otgParse.checkSessionUserP().then ()->
          return otgParse.findWorkorderP({status:'new'})
        .then (results)->
            return otgParse.createWorkorderP() if _.isEmpty(results)
            return results
          , (error)->
            return otgParse.createWorkorderP()
        .then (workorderObj)->
          $scope.workorderObj = workorderObj
          return otgUploader.startUploadingP(workorderObj, 2, $scope.cameraRoll_DATA.photos)
        .then ()->
          console.log "UPLOAD COMPLETE!!!"

    }

    init =()->
      if otgUploader.enable()==null
        otgUploader.enable($scope.config.upload['auto-upload'])

    init() 

]
