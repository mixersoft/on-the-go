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
  '$scope', '$rootScope', '$timeout', '$q', '$ionicTabsDelegate', 'otgData', 'otgWorkorder', 'otgWorkorderSync', 'otgParse', 'otgUploader', 'cameraRoll','TEST_DATA',
  ($scope, $rootScope, $timeout, $q, $ionicTabsDelegate, otgData, otgWorkorder, otgWorkorderSync, otgParse, otgUploader, cameraRoll, TEST_DATA) ->
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
      isOffline: ()->
        return $scope.deviceReady.isOnline() == false
      ngClass_UploadStatus: (order, prefix='badge')->
        return prefix + '-balanced' if order.count_expected == (order.count_received + order.count_duplicate)
        return prefix + '-energized'
      ngBind_UploadStatus: (order)->
        return 'ready' if order.count_expected == (order.count_received + order.count_duplicate)  
        return 'pending'

    }        

    $scope.on = {
      refresh: ()->
        $scope.DEBOUNCED_SYNC_cameraRoll_Orders()
        return      
    }

    # NOTE: ng-repat = order in filteredOrders = (workorders = $root.orders | filter:filterStatusNotComplete )
    # set by $scope.DEBOUNCED_SYNC_cameraRoll_Orders()
    _workorders = $rootScope.orders

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      return if !$scope.deviceReady.isOnline()
      $scope.showLoading(true)
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      return if !$scope.deviceReady.isOnline()
      $scope.DEBOUNCED_SYNC_cameraRoll_Orders()
      return


    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 
      

]




