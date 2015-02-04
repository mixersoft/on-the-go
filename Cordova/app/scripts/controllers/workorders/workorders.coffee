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
      refresh: ()->
        $scope.DEBOUNCED_SYNC_workorders()

      confirmReUploadPhotos: (order)->
        msg = "Are you sure you want to\nre-upload all photos for this order?"
        resp = window.confirm(msg)
        this.reUploadPhotos(order) if resp 
        return

      reUploadPhotos: (order)->
        # console.log order.objectId
        return otgParse.getWorkorderByIdP(order.objectId)
        .then (workorder)->
          # console.log workorder
          return otgParse.fetchWorkorderPhotosByWoIdP({workorder: workorder})
        .then (photosColl)->
          promises = []
          photosColl.each (photo)->
            # p = otgParse.updatePhotoP(photo, {src:'queued'}, false) # updates all photos by UUID, incl workorderObjs 
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

    $scope.DEBOUNCED_SYNC_workorders = _.debounce ()->
      console.log "\n\n >>> DEBOUNCED!!!"
      onComplete = ()->
        $scope.hideLoading()
        $scope.$broadcast('scroll.refreshComplete')
        return
      otgWorkorderSync.SYNC_WORKORDERS($scope, 'editor', 'force', onComplete)
    , 5000 # 5*60*1000
    , {
      leading: true
      trailing: false
    }

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      return if !$scope.deviceReady.isOnline()
      $scope.showLoading(true)
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      return if !$scope.deviceReady.isOnline()
      # cached view becomes active 
      # dynamically update left side menu
      $scope.SideMenuSwitcher.leftSide.src = 'partials/workorders/left-side-menu'
      $scope.SideMenuSwitcher.watch['workorder'] = null
      $scope.DEBOUNCED_SYNC_workorders()
      return

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return   

]




