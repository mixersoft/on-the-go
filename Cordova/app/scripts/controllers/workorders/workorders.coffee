'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:WorkordersCtrl
 # @description
 # # WorkordersCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')

.controller 'WorkordersCtrl', [
  '$scope', '$rootScope', '$timeout', '$q', 'SideMenuSwitcher', '$ionicTabsDelegate', 'otgData', 'otgWorkorder', 'deviceReady', 'otgWorkorderSync', 'otgParse', 'TEST_DATA',
  ($scope, $rootScope, $timeout, $q, SideMenuSwitcher, $ionicTabsDelegate, otgData, otgWorkorder, deviceReady, otgWorkorderSync, otgParse, TEST_DATA) ->
    $scope.label = {
      title: "Workorders"
      subtitle: "Workorder Management System"
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


    $scope.on = {
      reUploadPhotos: (order)->
        # console.log order.objectId
        return otgParse.getWorkorderByIdP(order.objectId)
        .then (workorder)->
          # console.log workorder
          return otgParse.fetchWorkorderPhotosByWoIdP({workorder: workorder})
        .then (photosColl)->
          promises = []
          photosColl.each (photo)->
            p = photo.set('src','queued').save().then (o)->
                # console.log o
                return
              , (err)->
                console.log "ERROR reUploadPhotos, errr=" + JSON.stringify err
            promises.push p
          $q.all(promises).then ()->
            console.log "reUploadPhotos() complete for workorder.id=" + order.objectId




    }
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

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      # dynamically update left side menu
      $scope.SideMenuSwitcher.leftSide.src = 'partials/workorders/left-side-menu'
      $scope.SideMenuSwitcher.watch['workorder'] = null
      otgWorkorderSync.SYNC_WORKORDERS($scope, 'editor', 'force')
      return

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return   

]




