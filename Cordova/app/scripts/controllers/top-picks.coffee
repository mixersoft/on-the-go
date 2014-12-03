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
        id: null
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

      parsePhotosFromMoments : (moments)->
        photos = []
        _.each moments, (v,k,l)->
          if v['type'] == 'moment'
            _.each v['value'], (v2,k2,l2)->
              if v2['type'] == 'date'
                _.each v2['value'], (pid)->
                  photos.push _.defaults {
                      # id: pid, 
                      UUID: pid,
                      date: v2['key']
                    }, defaults_photo

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
# otgPreview is currently unused  
.directive 'otgPreview', [
    'TEST_DATA'
    (TEST_DATA)->
      default_options = {
        width: 320
        height: 240
      }
      return {
        # templateUrl: 'views/template/otg-preview.html'
        template: '<img ng-src="{{photo.src}}" height="{{photo.height}}">'
        restrict: 'EA'
        scope : false
          # photo: "=photo"
        link: (scope, element, attrs) ->
          # element.text 'this is the moment directive'
          if !scope.$parent.options?.width
            scope.$parent.options = _.defaults (scope.$parent.options || {}), default_options
          scope.crWidth = attrs['cr-width'] || '100%'
          options = _.clone scope.$parent.options 
          if !scope.photo?.height && (scope.photo.UUID[-5...-4]<'4')
            options.height = 400
          src =  TEST_DATA.lorempixel.getSrc(scope.photo.UUID, options.width, options.height, TEST_DATA)
          scope.photo.src = src
          # scope.photo.width = options.width
          scope.photo.height = options.height
          return
      }
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
  '$ionicPopup', '$ionicModal', '$ionicScrollDelegate', 
  'deviceReady', 'snappiMessengerPluginService', 'cameraRoll'
  'TEST_DATA', 'imageCacheSvc'
  ($scope, $rootScope, $state, otgData, otgParse, $timeout, $window, $q, $filter, $ionicPopup, $ionicModal, $ionicScrollDelegate, deviceReady, snappiMessengerPluginService, cameraRoll, TEST_DATA, imageCacheSvc) ->
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

    window.$state = $scope.$state = $state;

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
        if !item.scaledH > 0
          IMAGE_WIDTH = 300-2
          if deviceReady.isWebView() && item.originalWidth && item.originalHeight
            # console.log "index="+index+", UUID="+item.UUID+", origW="+item.originalWidth + " origH="+item.originalHeight
            h = item.originalHeight/item.originalWidth * IMAGE_WIDTH
          else # browser/TEST_DATA
                      h = item.height / 320 * IMAGE_WIDTH
          item.scaledH = h
          # console.log "index="+index+", scaledH="+h+" origH="+item.originalHeight+", index.UUID="+cameraRoll.photos[index].UUID
        else 
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
        confirmPopup = $ionicPopup.confirm {
          title: "Share Photo"
          template: "Are you sure you want to share this photo?"
        }
        confirmPopup.then (res)->
          item.shared = true if res
        return item  
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
        current = $scope.$state.current.name.split('.').pop()
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
        # $scope.loadCameraRollP().then ()->
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
      $img.attr('uuid', '12345')
      angular.element(container).append $img
      ImgCache.init()
      ImgCache.clearCache ()->
        console.log "\n*** ImageCache cleared *** \n"
      imageCacheSvc.cacheDataURLP($img, null, true)
      window.isCached = imageCacheSvc.isCachedP
      # imageCacheSvc.raw $img


    init = ()->
      cameraRoll.photos = cameraRoll.photos
      setFilter( $state.current )
      $scope.on.showInfo(true) if $scope.config['top-picks']?.info


      # return console.log "SKIPPING FETCH TOP PICKS FROM PARSE !!! "

      parse._fetchPhotosByOwnerP().then null, (err)->
          console.warn "PARSE error, err=" + JSON.stringify err
          return {}
      .then (o)->
        
        # merge topPicks with photoRoll
        # TODO: save to local storage
        # return "skip this for now"
        $scope.serverPhotos = o.photosColl.toJSON()
        _.each $scope.serverPhotos, (photo)->
          found = _.find cameraRoll.photos, (o)->return o.UUID[0...36] == photo.UUID
          if !found 
            # add to cameraRoll.photos
            # real workorder photos will NOT be found in TEST_DATA the FIRST time
            photo.UUID = photo.assetId
            photo.from = "PARSE"          # deprecate, TODO: keep track of server photos from workorders separately
            photo.date = cameraRoll.getDateFromLocalTime(photo.dateTaken)
            photo.topPick = !!photo.topPick
            cameraRoll.photos.push photo
          else 
            # merge values set by Editor
            # merge shotId
            _.extend found, _.pick photo, ['topPick', 'favorite', 'shotId', 'isBestshot']
            console.log "\n\n**** COPY topPick from serverPhotos for uuid=" + photo.assetId
          return true
        return 

      return

    init()
  ]




