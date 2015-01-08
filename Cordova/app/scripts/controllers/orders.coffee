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

    $scope.workorders = []

    init = ()->
      # show loading
      $scope.showLoading(true)
      force = true || !otgWorkorderSync._workorderColl['owner'].length
      if force
        otgWorkorderSync.SYNC_ORDERS(
          $scope, 
          'owner', 
          'force', 
          ()->return $scope.hideLoading(1000)
          )
      else 
        options = { owner: true }
        otgWorkorderSync.fetchWorkordersP( options ).then (workorderColl)->
          # console.log " \n\n 2: &&&&& REFRESH fetchWorkordersP from orders.coffee "
          $scope.workorders = workorderColl.toJSON()

          # update workorder Photo counts
          workorderColl.each (woObj)->
            return if woObj.get('status') == 'complete'
            otgWorkorderSync.updateWorkorderCounts(woObj)
            return
          $scope.hideLoading()  
          return


    init()  

]




