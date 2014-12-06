'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:OrdersCtrl
 # @description
 # # OrdersCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.directive 'otgMomentDateRange', [
# renders moment as a dateRange, used in Orders or Workorders  
# adds an end-cap not found in otgMoment
  'otgData'
  (otgData)->

    options = defaults = {
      breakpoint: 480
      'col-xs': 
        rows: 2
        btnClass: ''
        thumbnailSize: 58-2
        thumbnailLimit: null # (w-69)/thumbnailSize
      'col-sm':
        rows: 2
        btnClass: 'btn-lg'
        thumbnailSize: 74-2
        thumbnailLimit: null # (w-88)/thumbnailSize
    }

    _setSizes = (element)->
      # also $window.on 'resize'  
      w = element[0].parentNode.clientWidth
      # console.log w
      if w < options.breakpoint
        cfg = _.clone options['col-xs']
        cfg.thumbnailLimit = (w-69)/cfg.thumbnailSize
      else # .btn-lg
        cfg = _.clone options['col-sm']
        cfg.thumbnailLimit = (w-88)/cfg.thumbnailSize

      whitespace = cfg.thumbnailLimit % 1
      # console.log "whitespace=" + whitespace + ", pixels=" +(whitespace * cfg.thumbnailSize)
      if whitespace * cfg.thumbnailSize < 28 
        # leave room for .badge
        cfg.thumbnailLimit -= 1
      cfg.thumbnailLimit = Math.floor(cfg.thumbnailLimit)  
      # use single row output if we have room
      if cfg.thumbnailLimit > 5
        cfg.rows = 1 
        cfg.thumbnailLimit -= 1

      # console.log "directive:otgMoment thumbnailLimit=" + cfg.thumbnailLimit
      return cfg

    summarize = (selectedMoments, options)->
      # sample photos from dateRange
      # selectedMoments sorted by mostRecent
      first = selectedMoments[selectedMoments.length-1]
      last = selectedMoments[0]
      summary = {
        key: last.key
        dateRange: {}
        type: 'summaryMoment'
        value: []
      }
      end = first.value[0]
      start = last.value[ last.value.length-1 ]
      summary.dateRange.from = start.key
      summary.dateRange.to = end.key
      # sample photos, as necessary
      length = options.rows * options.thumbnailLimit



      photos = otgData.parsePhotosFromMoments selectedMoments  # mostRecent first
      # orders have only 1 selectedMoment, unlike choose
      # TODO:  use reduce with dateRange instead




      photos.reverse() # sorted by date, mostRecent last
      if photos.length <= options.thumbnailLimit 
        # not enough photos for 2 rows
        summary.value.push photos
        options.rows = 1
      else if photos.length <= length
        # not enough photos to sample, use all photos
        summary.value.push photos.splice(0,options.thumbnailLimit)
        summary.value.push photos
      else 
        # sample photos
        incr =  photos.length / length
        sampled = []
        ( (i)->sampled.push( photos[ Math.floor(i) ])  )(i) for i in [0..photos.length-1] by incr

        sampled[sampled.length-1] = photos[photos.length-1]  # force LAST photo
        if options.rows == 2
          summary.value.push sampled.splice(0, options.thumbnailLimit)
        summary.value.push sampled
      return summary

    self = {
      templateUrl:  'partials/otg-moment-date-range'
      restrict: 'EA'
      scope: 
        moments: '=otgModel'
      link: (scope, element, attrs)->
        scope.options = _setSizes(element)

        if scope.moments?.length
          scope.summaryMoment = summarize(scope.moments, scope.options) 
        return
    }
    return self
]
.controller 'OrdersCtrl', [
  '$scope', '$q', '$ionicTabsDelegate', 'otgData', 'otgWorkorder', 'otgParse', 'otgUploader', 'cameraRoll','TEST_DATA',
  ($scope, $q, $ionicTabsDelegate, otgData, otgWorkorder, otgParse, otgUploader, cameraRoll, TEST_DATA) ->
    $scope.label = {
      title: "Order History"
      subtitle: "Share something great today!"
    }

    $scope.gotoTab = (name)->
      switch name
        when 'complete'
          index = 1
        else 
          index = 0
      $ionicTabsDelegate.select(index)

    $scope.filterStatusNotComplete = (o)->
      return o if o.status? && o.status !='complete'
      if o.className == 'WorkorderObj'
        return o if o.get('status') !='complete'

    parse = {
      _fetchWorkordersP : ()->
        return otgParse.checkSessionUserP().then ()->
          return otgParse.fetchWorkordersByOwnerP()
        .then (workorderColl)->
          $scope.workorders = workorderColl.toJSON()      # .toJSON() -> readonly
          return workorderColl

      _fetchWorkorderPhotosP : (workorderObj)->
        return otgParse.checkSessionUserP().then ()->
          options = {
            workorder: workorderObj
            owner: true
          }
          return otgParse.fetchWorkorderPhotosByWoIdP(options)
        .then (photosColl)->
          return photosColl.toJSON()
  
      _queueSelectedMomentsP : (workorderObj)->

        # get workorderPhotosP() by UUID
        parse._fetchWorkorderPhotosP(workorderObj).then (photos)->
          # merge into cameraRoll, copied from top-picks.init(), refactor to otgParse
          _.each photos, (photo)->
            found = _.find cameraRoll.photos, (o)->return o.UUID[0...36] == photo.UUID
            if !found 
              # DONT add to cameraRoll.photos until after queue??
              photo.topPick = !!photo.topPick
              cameraRoll.photos.push photo
              console.log "\n\n**** NEW serverPhoto, uuid=" + photo.UUID
            else 
              # merge values set by Editor
              # merge shotId
              _.extend found, _.pick photo, ['topPick', 'favorite', 'shotId', 'isBestshot']
              console.log "\n\n**** MERGE topPick from serverPhotos for uuid=" + photo.UUID
            return true
          return photos

        .then (photos)->  
          console.log "\n\n workorder photo assetIds, length=" + photos.length
          assetIds = _.pluck photos, 'assetId'
          console.log assetIds
          return assetIds
        .then (workorderAssetIds)->
          # compare against selectedMoment UUIDs
          dateRange = otgWorkorder.on.selectByCalendar workorderObj.get('fromDate'), workorderObj.get('toDate')
          console.log dateRange # $$$
          # dateRange.from = '2014-09-03'
          # compare vs. map because cameraRoll.photos is incomplete
          mappedPhotos = cameraRoll.map() 
          mappedPhotos = cameraRoll.photos if _.isEmpty mappedPhotos
          cameraRollAssetIds = _.reduce mappedPhotos, (result, o)->
              o.date = cameraRoll.getDateFromLocalTime o.dateTaken if !o.date
              result.push o.UUID if dateRange.from <= o.date <= dateRange.to
              return result
            , []

          console.log "expected cameraRoll photos found="+cameraRollAssetIds.length

          missingPhotos = _.difference cameraRollAssetIds, workorderAssetIds

          return otgUploader.queueP(workorderObj, missingPhotos).then (queue)->
            console.log "workorder found and missing photos queued, length=" + queue.length
            return queue
    }
    $scope.workorders = []

    init = ()->
      $scope.orders = TEST_DATA.orders

      # from parse
      # show loading
      # TODO: move to appCtrl and check for missing assets on startup
      parse._fetchWorkordersP().then (workorderColl)->
        promises = []
        workorderColl.each (woObj)->
          wo = woObj.toJSON()
          missing = wo.count_expected - wo.count_duplicate - wo.count_received
          return if missing == 0
          console.log "\n\n workorder found with missing photos:"
          console.log wo
          promises.push parse._queueSelectedMomentsP( woObj ).then (queuedPhotos)->
            return

        return $q.all(promises)

    init()  

]




