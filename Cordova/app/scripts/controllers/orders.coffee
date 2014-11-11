'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:OrdersCtrl
 # @description
 # # OrdersCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.directive 'otgOrderMoment', [
  'otgData'
  (otgData)->
    options = defaults = {
      thumbnailLimit: 3
      thumbnailSize: 58-2
    }
    summarize = (selectedMoments, options)->
      # selectedMoments sorted by mostRecent
      first = selectedMoments[selectedMoments.length-1]
      last = selectedMoments[0]
      summary = {
        key: last.key
        type: 'summaryMoment'
        value: []
      }
      start = first.value[0]
      end = last.value[0]
      length = 2 * options.thumbnailLimit
      photos = otgData.parsePhotosFromMoments selectedMoments  # mostRecent first
      if photos.length <= options.thumbnailLimit 
        start.value = photos
      else if photos.length <= length
        start.value = photos.slice(0,options.thumbnailLimit)
        end.value = photos.slice(options.thumbnailLimit, length - 1)
      else 
        incr = Math.floor( photos.length / (length - 1) )
        sampled = []
        ( (i)->sampled.push( photos[ i ])  )(i) for i in [0..photos.length] by incr

        sampled[sampled.length-1] = photos[photos.length-1]  # force FIRST photo
        sampled.reverse()
        start.value = sampled.slice(0,3)
        end.value = sampled.slice(3,6) 
      summary.value.push(start)
      summary.value.push(end)
      return summary

    self = {
      templateUrl:  'partials/otg-summary-moment'
      restrict: 'EA'
      scope: 
        moments: '=otgModel'
      link: (scope, element, attrs)->
        scope.options = _.clone defaults
        if scope.moments.length
          scope.summaryMoment = summarize(scope.moments, scope.options) 
          scope.from = scope.summaryMoment.value[0]
          scope.to = scope.summaryMoment.value[1]
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




