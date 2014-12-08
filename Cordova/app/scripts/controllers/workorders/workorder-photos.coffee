'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:WorkorderPhotosCtrl
 # @description
 # # WorkorderPhotosCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.filter 'workorderPhotoFilter', ()->
  return (input, type='none')->
    switch type
      when 'none' 
        return input
      when 'todo' 
        # match = '2468ACE'   # match last CHAR of UUID
        return _.reduce input, (result, e, i)->
            result.push(e) if e.topPick != false &&  !e.topPick
            return result
          , [] 
      when 'picks'
        return _.reduce input, (result, e, i)->
            result.push(e) if e.topPick == true 
            return result
          , [] 

.directive 'workorderInProgressCard', [
# workorder-in-progress-card appears in the workorder left-side menu  
  '$q'
  ($q)->
    self = {
      templateUrl: 'partials/workorders/menu-workorder-snapshot'
      restrict: 'EA'
      scope:{
        order:'=ngModel'
      }
      link: (scope, element, attrs)->
        return
    }
    return self
]

.controller 'WorkorderPhotosCtrl', [
  '$scope', '$rootScope', '$state', '$q', 
  '$ionicSideMenuDelegate', '$ionicScrollDelegate', '$ionicPopup', 
  'otgData', 'otgParse', 'otgWorkorderSync', 'deviceReady', 'cameraRoll'
  '$timeout', '$filter', '$window', 'TEST_DATA', 
  ($scope, $rootScope, $state, $q, $ionicSideMenuDelegate, $ionicScrollDelegate, $ionicPopup, otgData, otgParse, otgWorkorderSync, deviceReady, cameraRoll, $timeout, $filter, $window, TEST_DATA) ->
    $scope.label = {
      title: "Workorder Photos"
      header_card: 
        'app.workorders.photos': 
          header: "Workorder Photos"
          body: "All photos from a customer workorder. Editors must select Top-picks from these photos. All photos must be scanned. "
          footer: ""
        'app.workorders.photos.new':
          header: "Favorites"
          body: "Only photos that are new and have not yet been reviewed."
          footer: ""  
        'app.workorders.photos.top-picks':
          header: "Shared"
          body: "A selection of Top Picks and Favorite Shots as selected by Editors. This is what the client will see."
          footer: ""  
    }

    # $scope.SideMenuSwitcher.leftSide.src = 'partials/workorders/left-side-menu'
    $scope.SideMenuSwitcher.watch['workorder'] = null


    # HACK: directive:workorderInProgressCard is NOT watching updates to
    # SideMenuSwitcher.watch.workorder (parent scope) from promise
    # so force redirect to working 'path', need a $apply() somewhere????
    mode = 'DEBUG'
    if mode!="DEBUG" && !$rootScope.workorderColl?
      return $state.transitionTo("app.workorders.all") 


    # filter photos based on $state.current
    setFilter = (toState)->
      switch toState.name
        when 'app.workorders.photos'
          $scope.filteredPhotos = $filter('workorderPhotoFilter')($scope.photos,'none')
        when 'app.workorders.photos.todo'
          $scope.filteredPhotos = $filter('workorderPhotoFilter')($scope.photos,'todo')
        when 'app.workorders.photos.picks'
          $scope.filteredPhotos = $filter('workorderPhotoFilter')($scope.photos,'picks')
      return    

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true
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
        event.preventDefault() if event
        revert = item.topPick
        return if revert==false
        item.topPick = false
        coll = $scope.parse_raw.photosColl
        otgParse.savePhotoP(item, coll, 'topPick').then ()->
            $scope.workorderAttr.progress.todo -= 1 if !revert && revert != false
            $scope.workorderAttr.progress.picks -= 1 if revert==true
            return $scope.$apply()
            # don't have to save to Parse yet
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if $state.current.name != 'app.workorders.photos'
          # refresh on reload
          # setFilter( $state.current )

        # scroll to next item()
        return item  
      addTopPick: (event, item)->
        event.preventDefault() if event
        revert = item.topPick
        return if revert==true
        item.topPick = true
        coll = $scope.parse_raw.photosColl
        otgParse.savePhotoP(item, coll, 'topPick').then ()->
            $scope.workorderAttr.progress.todo -= 1 if !revert && revert != false
            $scope.workorderAttr.progress.picks += 1 if revert==false
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
        current = $scope.$state.current.name.split('.').pop()
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
        return if deviceReady.isWebView()
        clickSide = ev.offsetX/ev.currentTarget.clientWidth
        clickSide = 'left' if clickSide < 0.33 
        clickSide = 'right' if clickSide > 0.67  
        switch clickSide
          when 'left' 
            scope.swipeCard.swipeOver('left')
          when 'right'
            scope.swipeCard.swipeOver('right')
    }

    $scope.data = {
      cardStyle : {
        width: '100%'
      }
    }


    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      setFilter(toState)   


    init = ()->
      woid = $state.params['woid']
      $scope.on.showInfo(true) if $scope.config['workorder.photos']?.info

      # show loading
      force = !otgWorkorderSync._workorderColl['editor'].length
      _whenDoneP = (workorderColl)->
        workorderObj = _.findWhere workorderColl.models, { id: woid } 
        otgWorkorderSync.fetchWorkorderPhotosP(workorderObj).then (photosColl)->
          $scope.photos = photosColl.toJSON()
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
          setFilter( $state.current )
          return
        return



      if force
        # only for TESTING when we load 'app.workorders.photos' as initial state!!!
        otgWorkorderSync.SYNC_WORKORDERS($scope, 'editor', 'force', _whenDoneP)
      else 
        workorderColl = otgWorkorderSync._workorderColl['editor']
        _whenDoneP workorderColl

      return

    init()
  ]




