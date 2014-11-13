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
      rows: 2
      breakpoint: 480
      'col-xs': 
        btnClass: ''
        thumbnailSize: 58-2
        thumbnailLimit: null # (w-69)/thumbnailSize
      'col-sm':
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

        if scope.moments.length
          scope.summaryMoment = summarize(scope.moments, scope.options) 
          scope
        return
    }
    return self
]
.controller 'OrdersCtrl', [
  '$scope', '$q', '$ionicTabsDelegate', 'otgData', 'otgWorkOrder', 'otgParse', 'TEST_DATA',
  ($scope, $q, $ionicTabsDelegate, otgData, otgWorkOrder, otgParse, TEST_DATA) ->
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
      _fetchWorkordersP : (options = {})->
        return otgParse.checkSessionUserP().then ()->
          return otgParse.fetchWorkordersByOwnerP(options)
        .then (results)->
          $scope.workorders = results.toJSON()      # .toJSON() -> readonly
          _.each $scope.workorders, (o)->
            # DEMO: recreate selectedMoments from dates
            otgWorkOrder.on.selectByCalendar(o.fromDate, o.toDate)
            o.selectedMoments = otgWorkOrder.checkout.getSelectedAsMoments().selectedMoments
            return
          return $q.when(results)  
    }
    $scope.workorders = []

    init = ()->
      $scope.orders = TEST_DATA.orders

      # from parse
      # show loading
      parse._fetchWorkordersP().then ()->
        # hide loading
        return

    init()  

]




