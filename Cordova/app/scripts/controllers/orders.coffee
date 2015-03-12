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
  '$scope', '$rootScope', '$timeout', '$q', '$ionicTabsDelegate', '$ionicNavBarDelegate', 'otgData', 'otgWorkorder', 'otgWorkorderSync', 'otgParse', 'otgUploader', 'cameraRoll',
  ($scope, $rootScope, $timeout, $q, $ionicTabsDelegate, $ionicNavBarDelegate, otgData, otgWorkorder, otgWorkorderSync, otgParse, otgUploader, cameraRoll) ->

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
      viewTitle: i18n.tr('title')  # HACK: view-title state transition mismatch  
    }        

    $scope.on = {
      refresh: ()->
        $scope.app.sync.DEBOUNCED_cameraRoll_Orders()
        return      
    }

    # NOTE: ng-repat = order in filteredOrders = (workorders = $root.orders | filter:filterStatusNotComplete )
    # set by $scope.app.sync.DEBOUNCED_cameraRoll_Orders()
    _workorders = $rootScope.orders

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      return

    $scope.$on '$ionicView.enter', ()->
      $scope.watch.viewTitle = i18n.tr('title')
      return if !$scope.deviceReady.isOnline()
      $timeout ()->
          $scope.showLoading(true)
          $scope.app.sync.DEBOUNCED_cameraRoll_Orders      

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 
      

]




