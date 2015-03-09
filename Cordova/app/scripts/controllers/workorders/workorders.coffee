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
  '$scope', '$rootScope', '$timeout', '$q', 'SideMenuSwitcher', '$ionicTabsDelegate', 'otgData', 'otgWorkorder', 'deviceReady', 'otgWorkorderSync', 'otgParse', 
  ($scope, $rootScope, $timeout, $q, SideMenuSwitcher, $ionicTabsDelegate, otgData, otgWorkorder, deviceReady, otgWorkorderSync, otgParse) ->
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
      status = 
        if o.className == 'WorkorderObj'
        then o.get('status') 
        else o.status
      return o if /^(complete|closed)/.test( status ) == false

    $scope.on = {
      refresh: ()->
        $scope.DEBOUNCED_SYNC_workorders()

      confirmReUploadPhotos: (order)->
        msg = "Are you sure you want to\nre-upload all photos for this order?"
        resp = window.confirm(msg)
        this.reUploadPhotos(order) if resp 
        return

      ###
      # @params status String: [new, ready, working, complete, rejected, closed]
      ###
      setStatus: (order, status)->
        THRESHOLD = {
          WORKING: 0.9
          COMPLETE: 0.9
        }

        return false if status == 'new'  
        oldStatus = order.status
        switch status
          when 'working'
            return false if order.count_received/order.count_expected < THRESHOLD.WORKING
          when 'complete'
            return false if order.status != 'working'
            return false if (1 - order.progress.todo/order.count_expected) < THRESHOLD.COMPLETE
          when 'reject'
            return false if order.status != 'complete'
          when 'closed'
            return false if order.status != 'complete'
        woObj = otgWorkorderSync._workorderColl['editor'].get( order.objectId )
        promise = otgParse.updateWorkorderP(woObj, {status:status}, ['status'])
        .then (woObj)->
            order.status = woObj.get('status')
            $scope.$apply()
          , (err)->
            order.status = oldStatus # rollback
            $scope.$apply()
            throw err
        return true



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
    $scope.watch = _watch = {}
    $scope.workorders = []
    $scope.workorder = null

    $scope.DEBOUNCED_SYNC_workorders = _.debounce ()->
      # console.log "\n\n >>> DEBOUNCED!!!"
      onComplete = ()->
        $scope.hideLoading()
        $rootScope.$broadcast('scroll.refreshComplete')
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
      $scope.SideMenuSwitcher.leftSide.src = 'views/partials/workorders/left-side-menu.html'
      $scope.SideMenuSwitcher.watch['workorder'] = null
      $scope.DEBOUNCED_SYNC_workorders()
      return

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return   

]




