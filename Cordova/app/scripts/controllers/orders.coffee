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

    $scope.filterStatusComplete = (o)->
      return o if $rootScope.$state.includes('app.orders.detail')
      status = 
        if o.className == 'WorkorderObj'
        then o.get('status') 
        else o.status
      return o if /^(complete|closed)/.test( status ) == true  

    $scope.filterStatusNotComplete = (o)->
      return o if $rootScope.$state.includes('app.orders.detail')
      status = 
        if o.className == 'WorkorderObj'
        then o.get('status') 
        else o.status
      return o if /^(complete|closed)/.test( status ) == false

    $scope.watch = _watch = {
      isOffline: ()->
        return $scope.deviceReady.isOnline() == false
      viewTitle: i18n.tr('title')  # HACK: view-title state transition mismatch  
      isSyncing: false
      showActionBtn: (order, action)->
        switch action
          when 'accept', 'export', 'upload-full-res'
            return true if /^(complete|closed)/.test order.status
            return false
    }        

    $scope.on = {
      refresh: ()->
        _SyncOrders()
        return      
      setStatus: (order, status)->
        switch status
          when 'closed'
            return if order.status!='complete'
        return
      view : (order)->
        $rootScope.$state.transitionTo('app.top-picks.top-picks', {woid: order.objectId})
        return
      reUploadAsFullRes : (order)->
        # console.log order.objectId
        return otgParse.getWorkorderByIdP(order.objectId)
        .then (workorder)->
          # console.log workorder
          return otgParse.fetchWorkorderPhotosByWoIdP({workorder: workorder})
        .then (photosColl)->
          promises = []
          photosColl.each (photo)->
            
            # p = otgParse.updatePhotoP(photo, {src:'queued'}, false) # updates all photos by UUID, incl workorderObjs 
            currentVal = photo.get('origSrc')
            # return if /^(ready|true)/.test currentVal

            if photo.get('topPick') && !photo.get('hideTopPick')
              value = 'queued'
            else if photo.get('favorite') && !photo.get('hideTopPick')
              value = 'queued'  
            else if currentVal == 'queued' # unset
              value = null
            else 
              return

            p = photo.set('origSrc', value).save().then (o)->
                # console.log o
                return
              , (err)->
                console.log "ERROR reUploadAsFullRes, err=" + JSON.stringify err
            promises.push p
            return
          $q.all(promises).then ()->
            console.log "reUploadAsFullRes() complete for workorder.id=" + order.objectId
        return 
      export: (order, filter='top-picks')->
        if $scope.deviceReady.device().isDevice
          msg = i18n.tr('export-redirect', 'app.orders')
          $scope.notifyService.message msg, 'info', 5000
          return
        exportUrl = [
          'http://app.snaphappi.com:8765/api'
          'containers'
          order.objectId
          'downloadContainer'
          filter
        ]
        woObj = otgWorkorderSync._workorderColl['owner'].get(order.objectId)
        accessToken = woObj.get('token')
        if accessToken
          promise = $q.when(accessToken)
        else 
          promise = otgParse.getAccessTokenP('WorkorderObj', woObj.id)
        return promise.then (token)->
          qs = [
            'access_token=' + token
            'archive_name=' + $rootScope.user.username + '-' + order.fromDate
          ]
          exportUrl = exportUrl.join('/') + '?' + decodeURIComponent( qs.join('&') )
          console.log "exportUrl=", exportUrl
          # save to scope
          order.exportUrl = exportUrl
          return 
        return
    }

    $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      # console.log '$stateChangeSuccess=', $rootScope.$state.current.name
      if $rootScope.$state.includes('app.orders.detail')
        if !$rootScope.$state.params?.oid
          $rootScope.$state.transitionTo('app.orders.open') 
        else 
          console.log "order.detail, id=", $rootScope.$state.params 

      return   

    $scope.$on 'sync.debounceComplete', ()->
      $scope.watch.isSyncing = false
      return

    _SyncOrders = (woid)->
      $scope.showLoading(true)
      $scope.watch.isSyncing = true
      options = {
        whenDoneP: (woColl)->
          $scope.watch.isSyncing = false
          $scope.hideLoading()
          # console.log "whenDone, ", woColl.toJSON() if woColl instanceof Parse.Collection
          $scope.watch.orders = woColl.toJSON()
          $rootScope.$broadcast('scroll.refreshComplete')
      }
      $scope.app.sync.cameraRoll_Orders( options )
      return

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      $scope.watch.orders = otgWorkorderSync._workorderColl['owner'].toJSON?()
      return

    $scope.$on '$ionicView.enter', ()->
      $scope.watch.viewTitle = i18n.tr('title')
      return if !$scope.deviceReady.isOnline()
      if !$scope.watch.isSyncing
        $timeout ()->
          woid = 
            if $rootScope.$state.includes('app.orders.detail')
            then $rootScope.$state.params.oid 
            else null
           _SyncOrders( woid )
          return



    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 
      

]




