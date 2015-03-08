'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:WorkorderPhotosCtrl
 # @description
 # # WorkorderPhotosCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')


.controller 'WorkorderPhotosCtrl', [
  '$scope', '$rootScope', '$state', '$q', 
  '$ionicSideMenuDelegate', '$ionicScrollDelegate', '$ionicPopup', 
  'otgData', 'otgParse', 'otgWorkorderSync', 'deviceReady', 'cameraRoll'
  '$timeout', '$filter', '$window'
  ($scope, $rootScope, $state, $q, $ionicSideMenuDelegate, $ionicScrollDelegate, $ionicPopup, otgData, otgParse, otgWorkorderSync, deviceReady, cameraRoll, $timeout, $filter, $window) ->
    $scope.label = {
      title: "Workorder Photos"
      header_card: 
        'app.workorders.photos.all': 
          header: "Workorder Photos"
          body: "All photos from a customer workorder. Editors must select Top-picks from these photos. All photos must be scanned. "
          footer: ""
        'app.workorders.photos.todo':
          header: "Favorites"
          body: "Only photos that are new and have not yet been reviewed."
          footer: ""  
        'app.workorders.photos.picks':
          header: "Shared"
          body: "A selection of Top Picks and Favorite Shots as selected by Editors. This is what the client will see."
          footer: ""  
    }

    # $scope.SideMenuSwitcher.leftSide.src = 'views/partials/workorders/left-side-menu.html'
    $scope.SideMenuSwitcher.watch['workorder'] = null


    # HACK: directive:workorderInProgressCard is NOT watching updates to
    # SideMenuSwitcher.watch.workorder (parent scope) from promise
    # so force redirect to working 'path', need a $apply() somewhere????
    mode = 'DEBUG'
    if mode!="DEBUG" && !$rootScope.workorderColl?
      return $state.transitionTo("app.workorders.all") 


    $scope.watch = _watch = {
      filteredOrderedPhotos : []
      filter: null
      orderBy: 
        key: 'dateTaken'
        reverse: false
      getHeaderLabel: (photo, keys)->
        label = _.pick( photo, keys )
        label.dateTaken = $filter('date')(photo.dateTaken, 'MM/dd/yyyy @ h:mma' ) if label.dateTaken
        if keys.indexOf('dim') > -1
          label.dim = [photo.originalWidth, photo.originalHeight].join('x')
        return photo.headerLabel = JSON.stringify(label).replace(/\"/g,'')
    }      

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true

      # apply filter | orderBy
      reloadDataSet: (toState)->
        toState = $state.current if `toState==null`
        switch toState.name
          when 'app.workorders.photos.all'
            _watch.filter = null
          when 'app.workorders.photos.todo'
            _watch.filter = {topPick:null}
          when 'app.workorders.photos.picks'
            _watch.filter = {topPick:true}
        data = $scope.photos
        data = $filter('filter')(data, _watch.filter)
        $scope.watch.filteredOrderedPhotos = $filter('orderBy')(data, _watch.orderBy.key, _watch.orderBy.reverse)


      getItemHeight : (item, index)->
        IMAGE_WIDTH = Math.min(deviceReady.contentWidth()-22, 640)
        scaledDim = cameraRoll.getCollectionRepeatHeight(item, IMAGE_WIDTH)
        h = item.scaledH
        h += ( 2 * 6 ) # paddingV
        h += 90 if $scope.on.showInfo()
        # console.log "\n\n >>> height=" + h + "\n\n"
        return h

      showInfo: (value=null)->
        return $scope.on._info if value == null 
        revert = $scope.on._info
        if value=='toggle'
          $scope.on._info = !$scope.on._info 
        else if value != null 
          $scope.on._info = value
        $ionicScrollDelegate.$getByHandle('collection-repeat-wrap').resize() if $scope.on._info != revert
        return $scope.on._info  


      notTopPick: (event, item)->
        if event
          event.preventDefault() 
          event.stopPropagation()
        revert = item.topPick
        return if revert==false
        item.topPick = false
        otgParse.savePhotoP(item, $scope.photosColl, 'topPick')
        # otgParse.updatePhotoP(item, 'topPick')
        .then ()->
            $scope.workorderAttr.progress.todo -= 1 if !revert && revert != false
            $scope.workorderAttr.progress.picks -= 1 if revert==true
            return $scope.$apply()
            # don't have to save to Parse yet
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if $state.current.name != 'app.workorders.photos.all'
          # refresh on reload
          # setFilter( $state.current )

        # scroll to next item()
        return item  
      addTopPick: (event, item)->
        if event
          event.preventDefault() 
          event.stopPropagation()
        revert = item.topPick
        return if revert==true
        item.topPick = true
        otgParse.savePhotoP(item, $scope.photosColl, 'topPick')
        # otgParse.updatePhotoP(item, 'topPick')
        .then ()->
            $scope.workorderAttr.progress.todo -= 1 if !revert && revert != false
            $scope.workorderAttr.progress.picks += 1 if !revert
            return $scope.$apply()
            # don't have to save to Parse yet
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if  $state.current.name != 'app.workorders.photos'
          # refresh on reload
          # setFilter( $state.current )

        # scroll to next item()
        return item  

      dontShowHint : (hide, keep)->
        # check config['dont-show-again'] to see if we should hide hint card
        current = $rootScope.$state.current.name.split('.').pop()
        if hide?.swipeCard
          property = $scope.config['dont-show-again']['workorders']
          property[current] = true
          $timeout ()->
              return hide.swipeCard.resetPosition()
            , 500
          return 
        return $scope.config['dont-show-again']['workorders']?[current]


      # swipeCard methods
      cardKeep: (item)->
        return $scope.on.addTopPick(null, item)
      cardReject: (item)->
        return $scope.on.notTopPick(null, item)
      cardSwiped: (item)->
        # console.log "Swipe, item.id=" + item.id
        return  
      cardClick: (scope, ev, item)->
        return if deviceReady.device().isDevice
        clickSide = ev.offsetX/ev.currentTarget.clientWidth
        clickSide = 'left' if clickSide < 0.33 
        clickSide = 'right' if clickSide > 0.67  
        switch clickSide
          when 'left' 
            scope.swipeCard.swipeOver('left')
          when 'right'
            scope.swipeCard.swipeOver('right')
      refresh: ()->
        $scope.on.reloadDataSet() 
        $rootScope.$broadcast('scroll.refreshComplete')

    }


    # for preview/grid view
    $scope.data = {
      cardStyle : {
        width: '100%'
      }
    }



    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      $scope.on.reloadDataSet() if $state.includes('app.workorders.photos')
      return

    $scope.$on 'sync.workordersComplete', ()->
      console.log '@@@ sync.workordersComplete'



    _force = false   
    $scope.$on '$ionicView.loaded', ()->
      # for testing: loading 'app/workorders/[woid]/photos' directly
      _force = !otgWorkorderSync._workorderColl['editor'].length
      return

    $scope.$on '$ionicView.beforeEnter', ()->
        # cached view becomes active 

        woid = $state.params['woid']
        $scope.on.showInfo(true) if $scope.config['workorder.photos']?.info
        # show loading
        _whenDoneP = (workorderColl)->
          workorderObj = _.findWhere workorderColl.models, { id: woid } 
          otgWorkorderSync.fetchWorkorderPhotosP(workorderObj).then (photosColl)->

            $scope.photosColl = photosColl
            uploadedPhotos = _.filter photosColl.toJSON(), (photo)->
              return photo.src[0...4] == 'http'
            uploadedPhotoIds = _.indexBy uploadedPhotos, 'UUID'
            $scope.photos = _.filter cameraRoll.map(), (o)->
              return uploadedPhotoIds[o.UUID]?
            # add to sideMenu
            $scope.workorderAttr = workorderObj.toJSON()
            $scope.SideMenuSwitcher.watch['workorder'] = $scope.workorderAttr 

            # # debug
            # window.debug.sms = $scope.SideMenuSwitcher.watch
            # window.debug.root = $rootScope

            # update work in progress counts
            woProgress = _.reduce $scope.photos, (result, item)->
                result.picks += 1 if item.topPick == true
                result.todo +=1 if !item.topPick && item.topPick != false
                return result
              , {
                todo: 0
                picks: 0 
              }

            workorderObj.save({progress: woProgress})
            $scope.on.reloadDataSet() 
            _force = false
            return
          return



        if _force
          # only for TESTING when we load 'app.workorders.photos' as initial state!!!
          otgWorkorderSync.SYNC_WORKORDERS($scope, 'editor', 'force', _whenDoneP)
        else 
          workorderColl = otgWorkorderSync._workorderColl['editor']
          _whenDoneP workorderColl

        return
      return 


    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 
  ]




