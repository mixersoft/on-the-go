'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:GalleryCtrl
 # @description
 # # GalleryCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.factory 'otgData', [
  ()->
    DAY_MS = 24*60*60*1000
    defaults_photo = {
        UUID: null
        dateTaken: null
        rating: null 
        favorite: false
        shared: false
        caption: null
        exif: {}
        # demo properties
        height: null
        src: null   # see: AppCtrl/otgPreview for lorempixel src
    }
    self = {
      _getAsLocalTime : (d, asJSON=true)->
        d = new Date() if !d    # now
        throw "_getAsLocalTimeJSON: expecting a Date param" if !_.isDate(d)
        d.setHours(d.getHours() - d.getTimezoneOffset() / 60)
        return d.toJSON() if asJSON
        return d

      parseIOSCollections: (collections)->
        # expecting [ {startDate: , endDate:, localizedTitle: , localizedLocationNames: , moments: [] , collectionListSubtype: , collectionListType: },{}]
        # moments = [ {startDate: , endDate:, localizedLocationNames: , "localizedTitle" , assetCollectionSubtype: ,assetCollectionType: ,assets: ,estimatedAssetCount: }, {} ]
        # parsed = []
        byDate = {}
        _.each collections, (collection)->
          # oneC = _.pick collection, ['startDate', 'endDate', 'localizedTitle', 'localizedLocationNames']
          # oneC.moments = []
          _.each collection.moments, (moment)->
            oneM = _.pick moment, ['startDate' , 'endDate', 'localizedTitle', 'localizedLocationNames']
            return if !oneM['localizedTitle']

            oneM.count = moment['estimatedAssetCount']
            dates = _.unique [oneM.startDate, oneM.endDate]  # TODO: fill in the dateRange
            _.each dates, (date)->
              byDate[date] = [0] if !byDate[date]
              lastCount = byDate[date].shift()
              byDate[date] = _.unique byDate[date].concat [oneM['localizedTitle']], oneM['localizedLocationNames']
              byDate[date].unshift( lastCount + oneM.count )
              return

            return 
          return
          # parsed.push oneC
          # return { date: [ count, label, loc, loc ], date:[], etc. }
        return byDate



      mapDateTakenByDays: (photos )->
        ## in: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
        # out: {2014-07-14:[{dateTaken: UUID: }, ]}
        return _.reduce photos, (result, o)->
            if !o.dateTaken
              # dateTaken missing, assume Browser, done in _LOAD_BROWSER_TOOLS() 
              return result
              # o.dateTaken = new Date().toJSON()[0...10]
              # datetime = new Date(o.dateTaken) 
            else if o.dateTaken.indexOf('+')>-1
              datetime = new Date(o.dateTaken) 
              # console.log "compare times: " + datetime + "==" +o.dateTaken
            else 
              datetime = self._getAsLocalTime(o.dateTaken, false) # no TZ info

            datetime.setHours(0,0,0,0)
            day = self._getAsLocalTime( datetime, true)
            day = day.substring(0,10)  # like "2014-07-14"

            if result[day]?
              result[day].push o 
            else               
              result[day] = [o]

            return result
          , {}

      parsePhotosFromMoments : (moments, lookup=[])->
        photos = []
        localDefaults = _.clone defaults_photo
        if lookup == 'TEST_DATA'
          localDefaults['from'] = 'TEST_DATA'

        _.each moments, (v,k,l)->
          if v['type'] == 'moment'
            _.each v['value'], (v2,k2,l2)->
              if v2['type'] == 'date'
                _.each v2['value'], (pid)->
                  if _.isArray lookup
                    photo = _.find(lookup,{UUID:pid}) 
                  if !photo 
                    photo = _.defaults {
                        UUID: pid,
                        date: v2['key']
                      }, localDefaults
                  photos.push photo
        # console.log photos 
        return photos

      # expecting { `date`: [array of photoIds]}
      parseMomentsFromCameraRollByDate : (cameraRollDates)->
        dates = _.keys cameraRollDates
        dates.sort()
        # console.log dates

        # cluster into moments
        _current = _last = null
        moments = _.reduce dates, (result, k)->
            date = if _.isDate(k) then k else new Date(k)
            if _current? 
              # ??? use cameraRoll.getDateFromLocalTime()???
              if date.setHours(0,0,0,0) == _last + DAY_MS # next day
                _last = date.setHours(0,0,0,0)
                _current.days[k] = cameraRollDates[k]   # or _.pluck UUID
              else 
                _current = _last = null    

            if !_current?
              # ???: use $dateParser?
              _last = date.setHours(0,0,0,0)
              o = {}
              o[k] = cameraRollDates[k]  # or _.pluck UUID
              _current = { label: k, days: o }
              result[_current.label] =  _current.days 

            return result
          , {}
        # console.log moments 
        return moments

        # reformat object as an array of {key:, value: }
      orderMomentsByDescendingKey : (o, levels=1)->
          keys = _.keys( o ).sort().reverse()
          recurse = levels - 1
          reversed = _.map keys, (k)->
            item = { key: k }
            item.type = if recurse then 'moment' else 'date'
            item.value = if recurse > 0 then self.orderMomentsByDescendingKey( o[k], recurse ) else o[k]

            # console.log item
            return item
          # console.log reversed if levels==2
          return reversed  


    }
    return self 
  ]

.factory 'otgImgCache', ['$q', '$ionicPlatform'
    ($q, $ionicPlatform)->
      return if !ImgCache
      deferred = $q.defer()

      $ionicPlatform.ready ()->
        if !window.cordova
          # console.warn 'ImgCache: Cordova not available'
          deferred.reject('ImgCache: Cordova not available') 
        else 
          ImgCache.options.debug = true;
          ImgCache.init ()->
              console.log "ImgCache Init SUCCESS"
              deferred.resolve('ImgCache ready')
            , ()->
              console.warn "ImgCache Init ERROR"
              deferred.reject('ImgCache init ERROR')
              

      return {
        promise : deferred.promise
      }
]

      
.controller 'TopPicksCtrl', [
  '$scope', '$rootScope', '$state', 'otgData', 'otgParse', 
  '$timeout', '$window', '$q', '$filter', 
  '$ionicPopup', '$ionicModal', '$ionicScrollDelegate', 'PtrService', '$cordovaSocialSharing'
  'deviceReady', 'cameraRoll', 'otgWorkorderSync'
  'imageCacheSvc', '$cordovaFile'
  ($scope, $rootScope, $state, otgData, otgParse, $timeout, $window, $q, $filter, 
    $ionicPopup, $ionicModal, $ionicScrollDelegate, PtrService, $cordovaSocialSharing, 
    deviceReady, cameraRoll, otgWorkorderSync, imageCacheSvc, $cordovaFile) ->

    $scope.SideMenuSwitcher.leftSide.src = 'views/partials/left-side-menu.html'

    $scope.state = { # DEPRECATE???
      showDelete: false
      showReorder: false
      canSwipe: true
    };

    $scope.watch = _watch = {
      info: $scope.$localStorage['topPicks'].showInfo
      filteredOrderedPhotos : []
      filter: null
      orderBy: 
        key: 'dateTaken'
        reverse: true
      counts: $scope.$localStorage['topPicks'].counts # init
      $state: $state
      orderCount: $rootScope.counts['orders']
      viewTitle: i18n.tr('title')  # HACK: view-title state transition mismatch
      showAsTopPick: (item)->
        return if !item
        switch $state.current.name
          when 'app.top-picks.top-picks'
            return {
              'ion-ios-checkmark balanced':!item.hideTopPick, 
              'ion-ios-checkmark-outline assertive': item.hideTopPick
            }
          when 'app.top-picks.favorites', 'app.top-picks.shared'
            return {
              'ion-ios-checkmark balanced':item.topPick && !item.hideTopPick, 
              'ion-ios-checkmark-outline balanced': !item.topPick 
              'ion-ios-checkmark-outline assertive': item.topPick && item.hideTopPick
            }
    }

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      # apply filter | orderBy
      reloadDataSet: (toState)->
        toState = $state.current if `toState==null`
        switch toState.name
          when 'app.top-picks.top-picks'
            _watch.filter = {topPick:true}
          when 'app.top-picks.favorites'
            _watch.filter = {favorite:true}
          when 'app.top-picks.shared'
            _watch.filter = {shared:true}
        if $state.params.woid && $state.params.woid !='all'
          _watch.filter['workorderId'] = $state.params.woid
        data = cameraRoll.map()
        # reject photos from different owners. 
        # TODO: reject photos from non-participating workorders
        data = _.reject(data, (o)-> return o.ownerId && o.ownerId != $rootScope.sessionUser.id )
        data = $filter('filter')(data, _watch.filter)
        data = $filter('orderBy')(data, _watch.orderBy.key, _watch.orderBy.reverse)
        $scope.watch.filteredOrderedPhotos = data
        key = toState.name.split('.').pop()
        _watch.counts[key] = $scope.watch.filteredOrderedPhotos.length
        $rootScope.counts['top-picks'] = _watch.counts[key] if key == 'top-picks'

      getItemHeight : (item, index)->
        return 0 if !item
        IMAGE_WIDTH = Math.min(deviceReady.contentWidth()-22, 320)
        scaledH = cameraRoll.getCollectionRepeatHeight(item, IMAGE_WIDTH)
        cardPaddingV = ( 2 * 5 ) # paddingV
        h = scaledH + cardPaddingV  
        if $scope.on.showInfo()
          headerH = 35
          footerH = 31
          h += headerH + footerH
        # console.log ">>> height=" + h
        return h
      showInfo: (value)->
        return $scope.watch.info if `value==null`
        revert = $scope.watch.info
        
        $scope.watch.info = 
          if value=='toggle'
          then !$scope.watch.info 
          else !!value

        if $scope.watch.info != revert
          # added custom event handler to ionic.bundle.js
          # angular.element($window).triggerHandler('resize.collection-repeat');
          $ionicScrollDelegate.$getByHandle('collection-repeat-wrap').resize() 
        return $scope.watch.info  


      hideAsTopPick: (event, item)->
        if event
          event.preventDefault() 
          event.stopPropagation()
        switch $state.current.name
          when 'app.top-picks.top-picks'
            item.hideTopPick = !item.hideTopPick    
          when 'app.top-picks.favorites', 'app.top-picks.shared'
            # do Nothing if not topPick
            return if !item.topPick 
            item.hideTopPick = !item.hideTopPick   
        
        otgParse.updatePhotoP(item, 'hideTopPick').then ()->
          console.log "*** Success updated hideTopPick=", item.hideTopPick
        return 
      setFavorite: (event, item, value='toggle')->
        if event
          event.preventDefault() 
          event.stopPropagation()
        item.favorite = if value=='toggle' then !item.favorite else value
        otgParse.setFavoriteP(item).then ()->
          $rootScope.$broadcast 'sync.cameraRollChanged'
          console.log "*** Success updated favorite=", value
        return item
      addShare: (event, item)->
        event.preventDefault();
        event.stopPropagation()
        if deviceReady.device().isBrowser
          confirmPopup = $ionicPopup.alert {
            title: "Sharing Not Available"
            template: "Sorry, sharing is only available from a mobile device."
          }
          confirmPopup.then (res)->
          return item 

        selected = [item] # get Selected
        deviceReady.waitP().then ()->
          # return $scope.on.socialShare()
          options = {
            subject: 'from Snaphappi On-the-Go'
            message: 'shared from Snaphappi On-the-Go'
            image: _.pluck selected, 'src'
            link: null
          }
          $cordovaSocialSharing
            # .shareViaFacebook(options.message, options.image, options.link)
            .share(options.message, options.subject, options.image, options.link)
            .then (result)->
                console.log "\n\n*** Success socialSharing check for cancel, SocialPlugin.share result"
                console.log result
                item.shared = true
                # save to Parse
                otgParse.updatePhotoP(item, 'shared').then ()->
                  $rootScope.$broadcast 'sync.cameraRollChanged'
                  console.log "\n\n*** Success socialSharing"
              , (error)->
                cancelled = error == false
                return console.log "\n*** socialSharing CANCELLED"  if cancelled
                console.log "\n*** ERROR socialSharing:"  
                console.log error


      addCaption: (event, item)->
        event.preventDefault()
        event.stopPropagation()
        captionPopup = $ionicPopup.prompt {
          title: "Add a Caption"
          subTitle: "Something to capture the momeent"
          inputPlaceholder: " Enter caption"
        }
        captionPopup.then (res)->
          item.caption = res if res
        return item  

      dontShowHint : (hide, keep)->
        # check config['dont-show-again'] to see if we should hide hint card
        current = $rootScope.$state.current.name.split('.').pop()
        if hide?.swipeCard
          property = $scope.config['dont-show-again']['top-picks']
          property[current] = true
          $timeout ()->
              return hide.swipeCard.resetPosition()
            , 500
          return 
        return $scope.config['dont-show-again']['top-picks']?[current]

      # swipeCard methods
      cardKeep: (item, $index)->
        return $scope.on.setFavorite(null, item, true)
      cardReject: (item)->
        return $scope.on.setFavorite(null, item, false)
      cardSwiped: (item, $index)->
        # console.log "Swipe, item.UUID=" + item.UUID
        return
      cardClick: (scope, ev, item)->
        return if deviceReady.device().isDevice
        clickSide = ev.offsetX/ev.currentTarget.clientWidth
        clickSide = 'left' if clickSide < 0.33 
        clickSide = 'right' if clickSide > 0.67  
        switch clickSide
          when 'left' 
            scope.swipeCard.swipeOver?('left')
          when 'right'
            scope.swipeCard.swipeOver?('right')

      refresh: ()->
        options = null
        if $state.includes('app.top-picks.favorites')
          options = {
            type: 'favorites'
            size: 'preview'
          } 
        $scope.app.sync.cameraRoll_Orders(options)
        return 

      DEBOUNCED_cameraRollSnapshot : _.debounce ()->
          # console.log "\n\n >>> DEBOUNCED!!!"
          $scope.$localStorage['cameraRoll'].map = cameraRoll.map()
          return
        , 5000 # 5*60*1000
        , {
          leading: true
          trailing: false
        }



      test: ()->
        # $scope._TEST_nativeUploader()
        # _TEST_imageCacheSvc()
        return
    }

    # args = {changed:bool }
    $scope.$on 'sync.cameraRollComplete', (args)->
      if $state.includes('app.top-picks')
        # pickup iOS .favorite
        # TODO: push NEW favorites if we want to share with other devices in WO
        # console.log '@@@ sync.cameraRollComplete, args=' +JSON.stringify _.keys args
        $scope.on.reloadDataSet()
      return

    cameraRollSnapshot = _.debounce ()->

      
    $scope.$on 'sync.orderPhotosComplete', ()->
      if $state.includes('app.top-picks')
        # console.log '@@@ sync.ordersComplete'
        if $state.includes('app.top-picks.top-picks')
          $scope.on.reloadDataSet() 
        if $state.includes('app.top-picks.shared')
          $scope.on.reloadDataSet() 
      return


    $rootScope.$on 'sync.cameraRollChanged', ()->
      if $state.includes('app.top-picks')
        $scope.on.DEBOUNCED_cameraRollSnapshot()
        return


    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      if $state.includes('app.top-picks')
        $scope.on.reloadDataSet() 
      if $state.includes('app.top-picks.favorites') && 
        $scope.deviceReady.device().isDevice &&
        $scope.watch.favorites_initialized!=true
          options = {
              type: 'favorites'
              size: 'preview'
            } 
          cameraRoll.loadFavoritesP() # do NOT remap cameraRoll
          $scope.watch.favorites_initialized = true
          markup = '<div class="text-center"><i class="icon ion-load-b ion-spin"></i>&nbsp;scanning camera roll...</div>'
          $scope.notifyService.message markup, 'info', 2000
      return 

    $scope.cameraRoll = cameraRoll  # DEPRECATE???

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      # console.log '$ionicView.loaded'
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # console.log '$ionicView.beforeEnter', $state.current.name
      ## NOTE: beforeEnter does not fire on direct load
      # cached view becomes active 
      return 


    _debounced_PullToRefresh = _.debounce ()->
        $timeout ()->
          view = "collection-repeat-wrap"
          PtrService.triggerPtr(view)
          return
      , 10  * 60 * 1000 # 10 mins
      , {
          leading: true
          trailing: false
        }  

    $scope.$on '$ionicView.enter', ()->
      $scope.watch.viewTitle = i18n.tr('title')
      if $state.params.woid && $state.params.woid !='all'
        $scope.watch.viewTitle += " (filtered)"
      return if !$scope.deviceReady.isOnline()
      _debounced_PullToRefresh()
      # see: $scope.on.cameraRollSelected(), calendarSelected()

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return      
    

    init = ()->
      if _.isEmpty cameraRoll.map()
        cameraRoll.map( $scope.$localStorage['cameraRoll'].map )

      $scope.config['app-bootstrap'] = false
      $scope.deviceReady.waitP().then ()->
        # first time only
        if _.isEmpty cameraRoll.map()
          $scope.showLoading(true)
          $scope.app.sync.DEBOUNCED_cameraRoll_Orders()  # first time only
        else 
          # WARNING: lazySrc bug, uses lorempixel before 'deviceReady' fired
          $scope.on.reloadDataSet() # restored from localStorage

        # $scope.on.cameraRollUpdated()
        $timeout ()->$scope.hideSplash()
        return
      return

    init()
  ]




