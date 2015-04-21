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
        'app.workorder-photos.all': 
          header: "Workorder Photos"
          body: "All photos from a customer workorder. Editors must select Top-picks from these photos. All photos must be scanned. "
          footer: ""
        'app.workorder-photos.todo':
          header: "Favorites"
          body: "Only photos that are new and have not yet been reviewed."
          footer: ""  
        'app.workorder-photos.picks':
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
      nav:
        index: 0
        keyboard: false
    }      

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true

      # apply filter | orderBy
      filterByStatus: (toState)->
        toState = $state.current if `toState==null`
        switch toState.name
          when 'app.workorder-photos.all', 'app.demo.all'
            _watch.filter = null
          when 'app.workorder-photos.todo'
            _watch.filter = {topPick:null}
          when 'app.workorder-photos.picks', 'app.demo.picks'
            _watch.filter = {topPick:true}
        data = $scope.photos
        data = $filter('filter')(data, _watch.filter)
        $scope.watch.filteredOrderedPhotos = $filter('orderBy')(data, _watch.orderBy.key, _watch.orderBy.reverse)


      getItemHeight : (item, index)->
        return 0 if !item
        MAX_IMAGE_WIDTH = 480 # $max-preview-dim-workorder set in ionic.app.scss
        IMAGE_WIDTH = Math.min(deviceReady.contentWidth()-22, MAX_IMAGE_WIDTH)
        scaledDim = cameraRoll.getCollectionRepeatHeight(item, IMAGE_WIDTH)
        h = item.scaledH
        h += ( 2 * 6 ) # paddingV
        h += 68 if $scope.on.showInfo()
        # console.log "\n\n >>> height=" + h + "\n\n"
        return h

      showInfo: (value=null)->
        return $scope.on._info if value == null 
        revert = $scope.on._info
        if value=='toggle'
          $scope.on._info = !$scope.on._info 
        else if value != null 
          $scope.on._info = value
        
        if $scope.on._info != revert
          # added custom event handler to ionic.bundle.js
          # angular.element($window).triggerHandler('resize.collection-repeat'); 
          $ionicScrollDelegate.$getByHandle('collection-repeat-wrap').resize() 
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
            $scope.on._saveWoProgress($scope.workorderAttr)
            return $scope.$apply()
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if $state.current.name != 'app.workorder-photos.all'
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
            $scope.on._saveWoProgress($scope.workorderAttr)
            return $scope.$apply()
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if  $state.current.name != 'app.workorder-photos'
          # refresh on reload
          # setFilter( $state.current )

        # scroll to next item()
        return item  

      _saveWoProgress: (woAttr)->
        wo = otgWorkorderSync._workorderColl.editor.get(woAttr.objectId)
        wo.set('progress', woAttr.progress).save()
        return

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
      cardKeep: (item, index)->
        return $scope.on.addTopPick(null, item)
      cardReject: (item)->
        return $scope.on.notTopPick(null, item)
      cardSwiped: (item, $index)->
        $scope.watch.nav.index = $index
        # console.log "Swipe, item.id=" + item.id
        return  
      cardClick: (scope, ev, item, $index)->
        clickSide = ev.offsetX/ev.currentTarget.clientWidth
        clickSide = 'left' if clickSide < 0.33 
        clickSide = 'right' if clickSide > 0.67  
        switch clickSide
          when 'left' 
            scope.swipeCard.swipeOver('left')
          when 'right'
            scope.swipeCard.swipeOver('right')
      refresh: ()->
        if fullRefresh = true
          return _SyncWorkorderPhotos()
        $scope.on.filterByStatus() 
        $rootScope.$broadcast('scroll.refreshComplete')
        return

      # 
      # keyboard shortcuts
      #
      toggleKeyboard: (ev)->
        return if deviceReady.device().isDevice
        $scope.watch.nav.keyboard = !$scope.watch.nav.keyboard
        if $scope.watch.nav.keyboard
          ev.target.focus()
      keydown: (ev)->
        _getSwipeCard = (item)->
          img = document.querySelector('.workorder-photo-card img[UUID="' + item.UUID + '"]')
          elem = ionic.DomUtil.getParentWithClass(img, 'workorder-photo-card')
          return angular.element(elem)?.scope()?.swipeCard

        return if !$scope.watch.nav.keyboard 
        switch ev.keyCode
          when 38 # up
            $scope.on.nextItem(-1)
          when 40 , 32 # down, space
            $scope.on.nextItem(1)
          when 37 # left
            index = $scope.watch.nav.index
            item = $scope.watch.filteredOrderedPhotos[index]
            _getSwipeCard(item)?.swipeOver('left')
          when 39 # right
            index = $scope.watch.nav.index
            item = $scope.watch.filteredOrderedPhotos[index]
            _getSwipeCard(item)?.swipeOver('right')
        # console.log "ng-keydown", ev
      scrollToItem: (index)->
        $isd = $ionicScrollDelegate.$getByHandle('collection-repeat-wrap')
        $isv = $isd.$getByHandle('collection-repeat-wrap').getScrollView()
        scrollY = $isv.options['getDimensionsForItem'](index).primaryPos
        $isd.scrollTo(0, scrollY + $scope.watch.crOffsetY, 1)
      nextItem:(incr)->
        $scope.watch.nav.index += incr
        $scope.watch.nav.index = 0 if $scope.watch.nav.index < 0
        length = $scope.watch.filteredOrderedPhotos.length
        $scope.watch.nav.index = length-1 if $scope.watch.nav.index >= length
        $scope.on.scrollToItem($scope.watch.nav.index)
        return

    }


    # for preview/grid view
    $scope.data = {
      cardStyle : {
        width: '100%'
      }
    }

    # sync photos only
    _SyncWorkorderPhotos = (woObjOrId)->
      woObjOrId = $state.params['woid'] if `woObjOrId==null`
      if _.isString(woObjOrId)
        workorderColl = otgWorkorderSync._workorderColl['editor']
        workorderObj = _.findWhere workorderColl.models, { id: woObjOrId } 

      return if !workorderObj
      otgWorkorderSync.fetchWorkorderPhotosP(workorderObj).then (photosColl)->
          $scope.photosColl = photosColl
          uploadedPhotos = _.filter photosColl.toJSON(), (photo)->
            return photo.src[0...4] == 'http'
          uploadedPhotoIds = _.indexBy uploadedPhotos, 'UUID'
          $scope.photos = _.filter cameraRoll.map(), (o)->
            # Keep only photos with src="http://snappi.snaphappi.com/..."
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
          update = {
            progress: woProgress
          }
          if /^(ready|rejected)/.test workorderObj.get('status')
            update['status'] = 'working'
          promise = workorderObj.save(update).then (workorderObj)->
            _.extend $scope.workorderAttr,  workorderObj.toJSON()

          $scope.on.filterByStatus() 

          # clean up UX
          $scope.hideLoading()
          $rootScope.$broadcast('scroll.refreshComplete')
          console.log "workorder-photos Sync complete"
          return
        return

    $scope.DEBOUNCED_SYNC_workorderPhotos = _.debounce ()->
        # console.log "\n\n >>> DEBOUNCED!!!"
        _SyncWorkorderPhotos
      , 5000 # 5*60*1000
      , {
        leading: true
        trailing: false
      }




    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      $scope.on.filterByStatus() if $state.includes('app.workorder-photos')
      $scope.on.filterByStatus() if $state.includes('app.demo')
      return

    $scope.$on 'sync.workordersComplete', ()->
      console.log '@@@ sync.workordersComplete'


    $scope.$on 'user:sign-out', (args)->
      $scope.photosColl = []
      $scope.photos = []

    isBootstrap = null
    $scope.$on '$ionicView.loaded', ()->
      # for testing: loading 'app/workorders/[woid]/photos' directly
      isBootstrap = !otgWorkorderSync._workorderColl['editor'].length
      options = {force: isBootstrap}
      options['woid'] = $rootScope.$state.params?.woid || null
      if isBootstrap  # set on startup, $scope.$on '$ionicView.loaded'
          # only for TESTING when we load 'app.workorder-photos' as initial state!!!
          
          otgWorkorderSync.SYNC_WORKORDERS($scope, options, ()->
            _SyncWorkorderPhotos(options.woid)
            isBootstrap = false
            console.log "workorder Sync complete"
        )      
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      return

    $scope.$on '$ionicView.enter', ()->  
      # cached view becomes active 
      $scope.on.showInfo(true) if $scope.config['workorder.photos']?.info
      offset = ionic.DomUtil.getPositionInParent(document.getElementsByClassName('otg-cr-preview')[0])
      $scope.watch.crOffsetY = offset?.top || 0
      # show loading
      $scope.showLoading(true)
      return if isBootstrap

      options = {
        woid: $rootScope.$state.params?.woid || null
      } 
      _SyncWorkorderPhotos(options) 
      return 


    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 

      return 
  ]




