'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:WorkordersCtrl
 # @description
 # # WorkordersCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.directive 'uploadStatus', [
  ()->
    return {
      restrict: 'A'
      link: (scope, element, attrs) ->
        scope.ngClass_UploadStatus =  (order, prefix='badge')->
          return if !order
          return prefix + '-balanced' if order.count_expected == (order.count_received + order.count_duplicate)
          return prefix + '-energized'

        scope.ngBind_UploadStatus = (order)->
          return 'unknown' if !order
          return 'ready' if order.count_expected == (order.count_received + order.count_duplicate)  
          return 'pending'
        return
    }
]
.controller 'WorkordersCtrl', [
  '$scope', '$rootScope', '$timeout', '$q', 'SideMenuSwitcher', '$ionicTabsDelegate', 'otgData', 'otgWorkorder', 'deviceReady', 'otgWorkorderSync', 'otgParse', 'TEST_DATA',
  ($scope, $rootScope, $timeout, $q, SideMenuSwitcher, $ionicTabsDelegate, otgData, otgWorkorder, deviceReady, otgWorkorderSync, otgParse, TEST_DATA) ->
    $scope.label = {
      title: "Workorders"
      subtitle: "Workorder Management System"
    }

    # dynamically update left side menu
    $scope.SideMenuSwitcher.leftSide.src = 'partials/workorders/left-side-menu'
    $scope.SideMenuSwitcher.watch['workorder'] = null

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


    $scope.watch = _watch = {
      ngClass_UploadStatus: (order, prefix='badge')->
        return prefix + '-balanced' if order.count_expected == (order.count_received + order.count_duplicate)
        return prefix + '-energized'
      ngBind_UploadStatus: (order)->
        return 'ready' if order.count_expected == (order.count_received + order.count_duplicate)  
        return 'pending'

    }
    $scope.workorders = []
    $scope.workorder = null

    _SYNC_EDITOR_WORKORDERS = ()->
      # run AFTER cameraRoll loaded
      return if _.isEmpty $rootScope.sessionUser
      return if deviceReady.isWebView() && _.isEmpty cameraRoll.map()

      
      console.log "\n\n*** BEGIN Workorder Sync\n"
      otgWorkorderSync.fetchWorkordersP({ editor: true }, 'force').then (workorderColl)->
          promises = []
          openOrders = 0
          workorderColl.each (workorderObj)->

            return if workorderObj.get('status') == 'complete'
            openOrders++
            promises.push otgWorkorderSync.fetchWorkorderPhotosP(workorderObj, 'force').then (photosColl)->
              # queue = otgWorkorderSync.queueMissingPhotos( workorderObj, photosColl )
              # $scope.menu.uploader.count = otgUploader.queueLength()
              $scope.workorders = workorderColl.toJSON()  

            $scope.menu.orders.count = openOrders
            return
          $q.all( promises ).then (o)->
            $scope.workorders = workorderColl.toJSON()
            console.log "\n\n*** all workorders loaded\n"


    init = ()->
      ## use a $watch instead?
      $timeout ()->
        _SYNC_EDITOR_WORKORDERS()

      return

    init()  

]




