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

# not properly implemented
.directive 'imgCache', [ 'otgImgCache'
    (otgImgCache)->
      return {
        restrict: 'A'
        scope: false
        link: (scope, element, attrs)->
          otgImgCache.promise.then (o)->
              # return if !ImgCache || !ImgCache.ready
              url = attrs.ngSrc || attrs.src
              ImgCache.isCached url , (path, success)->
                return ImgCache.useCachedFile element if success
                ImgCache.cacheFile url, ()->
                    console.log "ImgCache: using cached file=" + url
                    return ImgCache.useCachedFile element 
                  , ()->
                    console.log "ImgCache: cache hit ERROR. file=" + url
          .catch (o)->
              console.warn "ImgCache error, msg=" + o
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
  'TEST_DATA', 'imageCacheSvc'
  ($scope, $rootScope, $state, otgData, otgParse, $timeout, $window, $q, $filter, $ionicPopup, $ionicModal, $ionicScrollDelegate, $cordovaSocialSharing, deviceReady, cameraRoll, otgWorkorderSync, TEST_DATA, imageCacheSvc) ->
    $scope.label = {
      title: "Top Picks"
      header_card: 
        'app.top-picks': 
          header: "Top Picks"
          body: "A selection of Top Picks from our Curators to help you re-live your favorite Moments"
          footer: ""
        'app.top-picks.favorites':
          header: "Favorites"
          body: "A selection of your Favorite Shots to help you re-live your favorite Moments"
          footer: ""  
        'app.top-picks.shared':
          header: "Shared"
          body: "A selection of Top Picks and Favorite Shots you have Shared from this App"
          footer: ""  
    }

    $scope.SideMenuSwitcher.leftSide.src = 'partials/left-side-menu'

    $scope.state = {
      showDelete: false
      showReorder: false
      canSwipe: true
    };


    # filter photos based on $state.current
    # TODO: use ion-tabs instead?
    setFilter = (toState)->
      switch toState.name
        when 'app.top-picks'
          $scope.filteredPhotos = $filter('ownerPhotosByType')(cameraRoll.photos,'topPicks')
        when 'app.top-picks.favorites'
          $scope.filteredPhotos = $filter('ownerPhotosByType')(cameraRoll.photos,'favorites')
        when 'app.top-picks.shared'
          $scope.filteredPhotos = $filter('ownerPhotosByType')(cameraRoll.photos,'shared')
      return    

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true

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
        if item.favorite == false && $state.current.name == 'app.top-picks.favorites'
          # ???: how do we remove from/refresh collection repeat??
          setFilter( $state.current )
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

      test: ()->
        _TEST_imageCacheSvc()
        # $scope.loadMomentsFromCameraRollP().then ()->
        #   $scope.filteredPhotos = $filter('ownerPhotosByType')(cameraRoll.photos,'topPicks')
        #   console.log "AFTER loading cameraRoll, filteredPhotos.length="+$scope.filteredPhotos.length

    }


    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      setFilter(toState)   

    $scope.cameraRoll = cameraRoll
    $scope.$watchCollection "cameraRoll.photos", (newV, oldV)->
      # console.log "\n\n %%% watched cameraRoll.photos change, update filter %%% \n\n"
      setFilter( $state.current )
      # update menu banner
      if $state.current.name == 'app.top-picks' 
        $scope.menu.top_picks.count = $scope.filteredPhotos.length 
      else 
        $scope.menu.top_picks.count = $filter('ownerPhotosByType')(cameraRoll.photos,'topPicks').length
      return


    parse = {
      _fetchPhotosByOwnerP : (options = {})->
        _options = options  # closure
        return otgParse.checkSessionUserP().then otgParse.checkSessionUserRoleP 
        .then ()->
          return otgParse.fetchPhotosByOwnerP(_options)
        .then (photosColl)->
          _options.photosColl = photosColl
          return _options
    }

    _testImg = new Image()
    _TEST_imageCacheSvc = ()->
      # test imgCache
      container = document.getElementsByClassName('item-text-wrap')[0]
      img =_testImg
      img.src = window.testDataURL
      # img.src = "img/ionic.png"
      img.width = 320
      $img = angular.element(img)
      $img.attr('uuid', '12345678')
      $img.attr('format', 'preview')
      angular.element(container).append $img
      ImgCache.init()
      # ImgCache.clearCache ()->
      #   console.log "\n*** ImageCache cleared *** \n"


      # imageCacheSvc.cacheDataURLP($img, null, true).then (o)->
      #     console.log "\n\n >>> cacheDataURLP success"
      #     console.log o 
      #   , (filePath)->
      #     console.log "\n\n >>> cacheDataURLP FAILED, try $ngCordovaFile for file="+filePath

      promise = imageCacheSvc.cordovaFile_USE_CACHED_P( $img ).then (fileURL)->
        console.log "\n\n imageCacheSvc has cached dataURL, path=" + fileURL


      window.isCached = imageCacheSvc.isCachedP
      # imageCacheSvc.raw $img


    init = ()->
      setFilter( $state.current )
      $scope.on.showInfo(true) if $scope.config['top-picks']?.info

      # show loading
      force = !otgWorkorderSync._workorderColl['owner'].length
      if force
        otgWorkorderSync.SYNC_ORDERS($scope, 'owner', 'force')

      return

    init()
  ]




