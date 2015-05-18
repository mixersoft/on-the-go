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

    $scope.gotoTab = (name)->
      switch name
        when 'complete'
          index = 1
        else 
          index = 0
      $ionicTabsDelegate.select(index)


    $scope.filterStatusComplete = (o)->
      return o if $rootScope.$state.includes('app.workorders.detail')
      status = 
        if o.className == 'WorkorderObj'
        then o.get('status') 
        else o.status
      return o if /^(complete|closed)/.test( status ) == true    

    $scope.filterStatusNotComplete = (o)->
      return !$scope.filterStatusComplete(o)

    $scope.on = {
      selectTab: (status)->
        return 'done in SYNC_WORKORDERS()'

      refresh: ()->
        _SyncWorkorders()

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
          else
            return false
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
            return if /^(ready|true)/.test photo.get('origSrc')
            # p = otgParse.updatePhotoP(photo, {src:'queued'}, false) # updates all photos by UUID, incl workorderObjs 
            p = photo.set('src','queued').save().then (o)->
                # console.log o
                return
              , (err)->
                console.log "ERROR reUploadPhotos, errr=" + JSON.stringify err
            promises.push p
          $q.all(promises).then ()->
            console.log "reUploadPhotos() complete for workorder.id=" + order.objectId

      # workorder actions
      doAction: (action, workorder)->
        # console.log 'workorder action clicked=', action
        switch action # add ng-click
          when 'open', 'review'
            $scope.on.setStatus(workorder, action)
            target = "app.workorder-photos.all"
            $rootScope.$state.transitionTo(target, {
              woid: workorder.objectId
              })
          when 'complete'
            $scope.on.setStatus(workorder, action)
          when 'close'
            $scope.on.setStatus(workorder, 'closed')
          when 'reject'
            $scope.on.setStatus(workorder, action)

    }
    $scope.watch = _watch = {
      viewTitle: i18n.tr('title')
      isSyncing: false
    }
    $scope.workorders = []
    $scope.workorder = null

    $scope.$on 'user:sign-out', (args)->
      $scope.workorders = []
      $scope.workorder = null

    $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      if $rootScope.$state.includes('app.workorders.detail')
        if _.isEmpty $rootScope.$state.params?.woid
          $rootScope.$state.transitionTo('app.workorders.open') 
      return   

    _SyncWorkorders = (woid)->
      $scope.watch.isSyncing = true
      onComplete = ()->
        $scope.watch.isSyncing = false
        $scope.hideLoading()
        $rootScope.$broadcast('scroll.refreshComplete')
        if $rootScope.$state.includes('app.workorders.detail')
          $scope.workorder = found = _.find $scope.workorders, {objectId: options.woid}
          $scope.workorder['showDetail'] = true if found

        console.log "workorder Sync complete"
        return
      $scope.showLoading(true)  
      options = {force: true}
      options['woid'] = woid if woid?
      return otgWorkorderSync.SYNC_WORKORDERS($scope, options,  onComplete)


    _DEBOUNCED_SYNC_workorders = _.debounce ()->
          # console.log "\n\n >>> DEBOUNCED!!!"
          _SyncWorkorders
        , 5000 # 5*60*1000
        , {
          leading: true
          trailing: false
        }

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      $scope.SideMenuSwitcher.watch['workorder'] = null
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      # dynamically update left side menu
      return


    $scope.$on '$ionicView.enter', ()->
      $scope.watch.viewTitle = i18n.tr('title')
      $scope.SideMenuSwitcher.leftSide.src = 'views/partials/workorders/left-side-menu.html'
      return if !$scope.deviceReady.isOnline()
      $timeout ()->
        if $rootScope.$state.includes('app.workorders.detail')
          return _SyncWorkorders($rootScope.$state.params.woid)
        return _DEBOUNCED_SYNC_workorders() if $scope.workorders.length
        return _SyncWorkorders()      
      

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return   

]




