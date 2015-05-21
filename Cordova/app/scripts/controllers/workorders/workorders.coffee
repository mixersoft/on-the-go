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
  '$scope', '$rootScope', '$timeout', '$q', 
  'SideMenuSwitcher'
  '$ionicTabsDelegate', 'PtrService' 
  'otgData', 'otgWorkorder', 'deviceReady', 'otgWorkorderSync', 'otgParse', 
  ($scope, $rootScope, $timeout, $q, SideMenuSwitcher, $ionicTabsDelegate, PtrService, otgData, otgWorkorder, deviceReady, otgWorkorderSync, otgParse) ->

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
      return o if $rootScope.$state.includes('app.workorders.detail')
      status = 
        if o.className == 'WorkorderObj'
        then o.get('status') 
        else o.status
      return o if /^(complete|closed)/.test( status ) == false

    $scope.on = {
      selectTab: (status)->
        return 'done in SYNC_WORKORDERS()'

      refresh: ()->
        woid = 
          if $rootScope.$state.includes('app.workorders.detail')
          then $rootScope.$state.params.woid
          else null
        _SyncWorkorders(woid)

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
        updateFields = {status:status}
        promise = otgParse.updateWorkorderP(woObj, updateFields)
        .then (woObj)->
            order.status = woObj.get('status')
            if order.status == 'complete'
              $timeout ()->
                # ???: move to Cloud code?
                  promise = otgWorkorderSync.setWorkorderMomentP(woObj, {
                    filterPicks: true
                    })
                  return
                ,1000
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
            if action=='open' && /^(complete|closed)/.test(workorder.status) == false
              $scope.on.setStatus(workorder, 'working')
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
      workorders: null
      workorder: null
    }

    $scope.$on 'user:sign-out', (args)->
      otgWorkorderSync._workorderColl['editor'] = null
      $scope.watch.workorders = []
      $scope.watch.workorder = null

    # $scope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams, error)-> 
    #   if $rootScope.$state.includes('app.workorders')
    #       console.log "stateChangeStart=", $rootScope.$state.current.name
    #       $scope.watch.startStateChange = Date.now()  

    $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      # if $rootScope.$state.includes('app.workorders')
        # console.log "stateChangeSuccess elapsed=", [$rootScope.$state.current.name, Date.now() - $scope.watch.startStateChange]
        # $scope.watch.startStateChange = null 
      if $rootScope.$state.includes('app.workorders.detail')
        if _.isEmpty $rootScope.$state.params?.woid
          $rootScope.$state.transitionTo('app.workorders.open') 
      return   

    _debounced_PullToRefresh = _.debounce ()->
        $timeout ()->
          view = "workorder-" + $rootScope.$state.current.name.split('.').pop()
          PtrService.triggerPtr(view)
          return
      , 10  * 60 * 1000 # 10 mins
      , {
          leading: true
          trailing: false
        }
          

    _SyncWorkorders = (woid)->
      return if $scope.watch.isSyncing
      $scope.watch.isSyncing = true
      options = {
        force: $rootScope.$state.includes('app.workorders.detail')
        whenDone : (woColl)->
          $scope.watch.isSyncing = false
          $rootScope.$broadcast('scroll.refreshComplete')
          $scope.watch.workorders = otgWorkorderSync._workorderColl['editor'].toJSON?()
          if $rootScope.$state.includes('app.workorders.detail')
            workorder = _.find $scope.watch.workorders, {objectId: woColl.get(woid)}
            workorder['showDetail'] = true 
          console.log "workorder Sync complete"
          return
      }
      options['woid'] = woid if woid?
      return otgWorkorderSync.SYNC_WORKORDERS(options,  options.whenDone)


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
      # console.log "workorder beforeEnter"
      $scope.watch.workorders = otgWorkorderSync._workorderColl['editor'].toJSON?()
      # dynamically update left side menu
      return


    $scope.$on '$ionicView.enter', ()->
      # console.log "workorder enter"
      $scope.watch.viewTitle = i18n.tr('title')
      $scope.SideMenuSwitcher.leftSide.src = 'views/partials/workorders/left-side-menu.html'
      return if !$scope.deviceReady.isOnline()
      _debounced_PullToRefresh() if !$scope.watch.isSyncing

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return   

]




