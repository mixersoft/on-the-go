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

      mapDateTakenByDays: (photos )->
        ## in: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
        # out: {2014-07-14:[{dateTaken: UUID: }, ]}
        return _.reduce photos, (result, o)->
            if o.dateTaken.indexOf('+')>-1
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

      parsePhotosFromMoments : (moments, source)->
        photos = []
        localDefaults = _.clone defaults_photo
        localDefaults['from'] = source if source
        _.each moments, (v,k,l)->
          if v['type'] == 'moment'
            _.each v['value'], (v2,k2,l2)->
              if v2['type'] == 'date'
                _.each v2['value'], (pid)->
                  photos.push _.defaults {
                      UUID: pid,
                      date: v2['key']
                    }, localDefaults

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

.filter 'ownerPhotosByType', ()->
  return (input, type='topPick')->
    switch type
      when 'topPicks' 
        return _.reduce input, (result, e, i)->
            result.push(e) if e.topPick == true
            return result
          , [] 
      when 'favorites' 
        # match = '2468ACE'   # match last CHAR of UUID
        return _.reduce input, (result, e, i)->
            result.push(e) if e.favorite == true
            return result
          , [] 
      when 'shared'
        return _.reduce input, (result, e, i)->
            result.push(e) if e.shared == true 
            return result
          , [] 
      
.controller 'TopPicksCtrl', [
  '$scope', '$rootScope', '$state', 'otgData', 'otgParse', 
  '$timeout', '$window', '$q', '$filter', 
  '$ionicPopup', '$ionicModal', '$ionicScrollDelegate', '$cordovaSocialSharing'
  'deviceReady', 'cameraRoll', 'otgWorkorderSync'
  'TEST_DATA', 'imageCacheSvc', '$cordovaFile'
  ($scope, $rootScope, $state, otgData, otgParse, $timeout, $window, $q, $filter, $ionicPopup, $ionicModal, $ionicScrollDelegate, $cordovaSocialSharing, deviceReady, cameraRoll, otgWorkorderSync, TEST_DATA, imageCacheSvc, $cordovaFile) ->

    $scope.SideMenuSwitcher.leftSide.src = 'partials/left-side-menu'

    $scope.state = { # DEPRECATE???
      showDelete: false
      showReorder: false
      canSwipe: true
    };


    $scope.watch = _watch = {
      filteredOrderedPhotos : []
      filter: null
      orderBy: 
        key: 'dateTaken'
        reverse: true
      counts:
        'top-picks': null
        favorites: null
        shared: null
    }

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true

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
        data = cameraRoll.map()
        data = $filter('filter')(data, _watch.filter)
        data = $filter('orderBy')(data, _watch.orderBy.key, _watch.orderBy.reverse)
        $scope.watch.filteredOrderedPhotos = data
        key = toState.name.split('.').pop()
        _watch.counts[key] = $scope.watch.filteredOrderedPhotos.length
        $rootScope.counts['top-picks'] = _watch.counts[key] if key == 'top-picks'



      # deprecate, use directive:lazy-src
      # getSrc: (item)->
      #   return '' if !item
      #   return item.src if item.src
      #   found = cameraRoll.getDataURL(item.UUID, 'preview')
      #   found = cameraRoll.getDataURL(item.UUID, 'thumbnail') if !found 
      #   return found

      getItemHeight : (item, index)->
        IMAGE_WIDTH = Math.min(deviceReady.contentWidth()-22, 320)
        h = cameraRoll.getCollectionRepeatHeight(item, IMAGE_WIDTH)
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
      addFavorite: (event, item)->
        event.preventDefault();
        event.stopPropagation()
        item.favorite = !item.favorite
        otgParse.updatePhotoP(item, 'favorite').then ()->
                  console.log "\n\n*** Success updated favorite"
        return item
      addShare: (event, item)->
        event.preventDefault();
        event.stopPropagation()
        if !deviceReady.isWebView()
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
      cardKeep: (item)->
        item.favorite = true
      cardReject: (item)->
        item.favorite = false
      cardSwiped: (item)->
        # console.log "Swipe, item.UUID=" + item.UUID
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

      refresh: ()->
        $scope.SYNC_cameraRoll_Orders()
        return 

      test: ()->
        $scope._TEST_nativeUploader()
        # _TEST_imageCacheSvc()
        # $scope.loadMomentsFromCameraRollP().then ()->
        #   $scope.filteredPhotos = $filter('ownerPhotosByType')(cameraRoll.map(),'topPicks')
        #   console.log "AFTER loading cameraRoll, filteredPhotos.length="+$scope.filteredPhotos.length

    }

    # args = {changed:bool }
    $scope.$on 'sync.cameraRollComplete', (args)->
      if $state.includes('app.top-picks')
        # pickup iOS .favorite
        # TODO: push NEW favorites if we want to share with other devices in WO
        console.log args
        console.log '@@@ sync.cameraRollComplete, args=' +JSON.stringify args
        $scope.on.reloadDataSet() if $state.includes('app.top-picks.favorites')
      return

      
    $scope.$on 'sync.ordersComplete', ()->
      if $state.includes('app.top-picks')
        console.log '@@@ sync.ordersComplete'
        if $state.includes('app.top-picks.top-picks')
          $scope.on.reloadDataSet() 
        if $state.includes('app.top-picks.shared')
          $scope.on.reloadDataSet() 
      return


    $rootScope.$on 'sync.cameraRollChanged', ()->
      if $state.includes('app.top-picks')
        # redundant?? sync.ordersComplete instead?
        $scope.on.reloadDataSet() 


    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      $scope.on.reloadDataSet() if $state.includes('app.top-picks')
      return 

    $scope.cameraRoll = cameraRoll  # DEPRECATE???

    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      console.log '$ionicView.loaded'
      $scope.on.showInfo(true) if $scope.config['top-picks']?.info
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      return if !$scope.deviceReady.isOnline()
      console.log "\n\n\n %%% ionicView.beforeEnter > DEBOUNCED_SYNC_cameraRoll_Orders "
      $scope.DEBOUNCED_SYNC_cameraRoll_Orders()

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return      

    

    init = ()->
      $scope.config['app-bootstrap'] = false
      $scope.deviceReady.waitP().then ()->
        # first time only
        $scope.showLoading(true)
        $scope.DEBOUNCED_SYNC_cameraRoll_Orders()  # first time only
        # $scope.on.cameraRollUpdated()
        $timeout ()->$scope.hideSplash()
        return
      return

    init()
  ]




