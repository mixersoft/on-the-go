'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:OrdersCtrl
 # @description
 # # OrdersCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')

.controller 'OrdersCtrl', [
  '$scope', '$timeout', '$q', '$ionicTabsDelegate', 'otgData', 'otgWorkorder', 'otgWorkorderSync', 'otgParse', 'otgUploader', 'cameraRoll','TEST_DATA',
  ($scope, $timeout, $q, $ionicTabsDelegate, otgData, otgWorkorder, otgWorkorderSync, otgParse, otgUploader, cameraRoll, TEST_DATA) ->
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

    $scope.watch = _watch = {
      ngClass_UploadStatus: (order, prefix='badge')->
        return prefix + '-balanced' if order.count_expected == (order.count_received + order.count_duplicate)
        return prefix + '-energized'
      ngBind_UploadStatus: (order)->
        return 'ready' if order.count_expected == (order.count_received + order.count_duplicate)  
        return 'pending'

    }        

    $scope.on = {
      refresh: ()->
        otgWorkorderSync.SYNC_ORDERS(
          $scope, 'owner', 'force'
          , ()->
            $scope.hideSplash()
            return $scope.$broadcast('scroll.refreshComplete');
        )        
    }

    $scope.workorders = []



    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      if !$scope.deviceReady.isOnline()
        return 

      $scope.showLoading(true)
      otgWorkorderSync.SYNC_ORDERS(
        $scope, 
        'owner', 
        'force', 
        ()->return $scope.hideLoading(1000)
      )
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      _force = !otgWorkorderSync._workorderColl['owner'].length
      return if !_force 
      return if !$scope.deviceReady.isOnline()
      $scope.showLoading(true)
      otgWorkorderSync.SYNC_ORDERS(
        $scope, 'owner', 'force'
        , ()->
          $scope.hideSplash()
          return $scope.hideLoading(300)
      )


    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 
      

]




