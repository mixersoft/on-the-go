'use strict'

###*
 # @ngdoc directive
 # @name onTheGoApp.service:directives
 # @description
 # # directives
###
angular.module('ionBlankApp') 
# load img.src from the following sources, in order of priority
#   imgCacheSvc (browser/WebView FileURL)
#   cameraRoll.dataURL[] (dataURL, FileURL or parse URL)
#   lorempixel (for brower debug)
# uses $q.promise to load src 
.directive 'lazySrc', [
  '$localStorage', 'PLUGIN_CAMERA_CONSTANTS', 'cameraRoll', 'imageCacheSvc', '$rootScope', 'TEST_DATA'
  ($localStorage, CAMERA, cameraRoll, imageCacheSvc, $rootScope, TEST_DATA)->

    _setLazySrc = (element, UUID, format)->
      throw "ERROR: asset is missing UUID" if !UUID
      IMAGE_SIZE = format || 'thumbnail'

      # priorities: stashed FileURL > cameraRoll.dataURL > photo.src
      scope = element.scope()
      photo = scope.item || scope.photo  # TODO: refactor in TopPicks, use scope.photo

      isWorkorder = $rootScope.$state.includes('app.workorders') || $rootScope.$state.includes('app.orders')
      isWorkorderMoment = IMAGE_SIZE=='thumbnail' && isWorkorder
      # WARNING: must be after $localStorage.waitP()
      isBrowser = $localStorage['device'].isBrowser

      # special condition, Editor Workstation with no local photos
      if isBrowser && photo?.from == 'PARSE' 
        # orders or workorders from PARSE, use photo.src
        if format == 'thumbnail'
          # TODO: workorder thumbnails should be resampled.
          "skip"
        url = cameraRoll.addParseURL(photo, format) # cache photo.src into dataURL
        return element.attr('src', url)  

      if isBrowser && photo && photo.from == 'PARSE' 
        # DEBUG mode on browser
        return element.attr('src', photo.src)  

      # return if isBrowser && !photo # digest cycle not ready yet  

      if isBrowser
        return _useLoremPixel(element, UUID, format)


      return imageCacheSvc.isStashed_P(UUID, format)
      .then (fileURL)->
        # 1. use isStashed FileURL
        element.attr('src', fileURL)
        return 
      .catch (error)->

        # NOTE: UUID is truncated to 36
        src = cameraRoll.getDataURL(UUID, IMAGE_SIZE) 
        if src  
          # 2. use cached cameraRoll.dataURLs
          # already cached in cameraRoll.dataURLs, but not yet stashed because of $timeout
          element.attr('src', src) 
          return 
        
        # console.log "\nlazySrc reports notCached in cameraRoll.dataURLs for format=" + format + ", UUID="+UUID
        if !isBrowser || isWorkorder
          # get with promise
          options = {
            size: IMAGE_SIZE
            DestinationType : CAMERA.DestinationType.FILE_URI 
          }
          return cameraRoll.getDataURL_P( UUID, options ).then (photo)->
              if element.attr('lazy-src') == photo.UUID
                # TODO: this should now be FILE_URL
                # confirm that collection-repeat has not reused the element
                # 3. fetch dataURL from cameraRoll, cache and stash
                element.attr('src', photo.data)
                dataType = if photo.data[0...10]=='data:image' then 'DATA_URL' else 'FILE_URI'
                if IMAGE_SIZE == 'preview' && dataType == 'DATA_URL'
                  imageCacheSvc.cordovaFile_USE_CACHED_P(element, photo.UUID, photo.data) 
                else if dataType == 'FILE_URI'
                  imageCacheSvc.stashFile(UUID, IMAGE_SIZE, photo.data, photo.dataSize) # FILE_URI
                else 
                  'not caching DATA_URL thumbnails'
              else
                'skp'
                # console.warn "\n\n*** WARNING: did collection repeat change the element before getDataUR
              return
          .catch (error)->
            console.error "_setLazySrc"
            console.error error # $$$
        

    _useLoremPixel = (element, UUID, format)->
      console.error "ERROR: using lorempixel from device" if $localStorage['device'].isDevice
      scope = element.scope()
      switch format
        when 'thumbnail'
          options = scope.options  # set by otgMoment`
          src = TEST_DATA.lorempixel.getSrc(UUID, options.thumbnailSize, options.thumbnailSize, TEST_DATA)
        when 'preview'
          src = scope.item?.src
          src = TEST_DATA.lorempixel.getSrc(UUID, scope.item.originalWidth, scope.item.originalHeight, TEST_DATA) if !src
      return element.attr('src', src)  # use ng-src here???


    return {
      restrict: 'A'
      scope: false
      link: (scope, element, attrs) ->
        format = attrs.format

        attrs.$observe 'lazySrc', (UUID)->
          # UUID = UUID[0...36] # localStorage might balk at '/' in pathname
          # console.log "\n\n $$$ attrs.$observe 'lazySrc', UUID+" + UUID
          element.attr('uuid', UUID)
          src = _setLazySrc(element, UUID, format) 
          console.error "ERROR: using lazySrc BEFORE deviceReady.waitP()" if $localStorage['device'].isDevice==null
          return src

        return
  }
]
#
# otgMoment: a sample of thumbnails from photos taken on the same day
#   ???: confirm sampling
#   orderBy date DESC
#   grouped by consecutive days 
# used by app.choose.camera-roll
#
.directive 'otgMoment', [
  
  '$window', 'otgWorkorder', 'cameraRoll', 'otgData'
  ($window, otgWorkorder, cameraRoll, otgData)->
    options = defaults = {
      breakpoint: 480
      'col-xs': 
        btnClass: ''
        thumbnailSize: 58-2
        thumbnailLimit: null # (w-69)/thumbnailSize
      'col-sm':
        btnClass: 'btn-lg'
        thumbnailSize: 74-2
        thumbnailLimit: null # (w-88)/thumbnailSize
    }

    _setSizes = (element)->
      # also $window.on 'resize'  
      w = window.innerWidth
      # console.log w
      if w < options.breakpoint
        cfg = _.clone options['col-xs']
        cfg.thumbnailLimit = (w-69)/cfg.thumbnailSize
      else # .btn-lg
        cfg = _.clone options['col-sm']
        cfg.thumbnailLimit = (w-88)/cfg.thumbnailSize

      whitespace = cfg.thumbnailLimit % 1
      # console.log "whitespace=" + whitespace + ", pixels=" +(whitespace * cfg.thumbnailSize)
      if whitespace * cfg.thumbnailSize < 50 
        # leave room for .badge
        cfg.thumbnailLimit -= 1
      cfg.thumbnailLimit = Math.floor(cfg.thumbnailLimit)  
      # console.log "directive:otgMoment thumbnailLimit=" + cfg.thumbnailLimit
      return cfg

    _lookupPhoto = null
    _getAsPhotos = (uuids)->
      return _.map uuids, (uuid)->
        photo = _lookupPhoto[uuid]
        if !photo
          photo = _.find(cameraRoll.map(),{UUID:uuid})
          if !photo
            console.warn ">>> otgMoment photo not found, UUID="+uuid if !photo
          else 
            _lookupPhoto[uuid] = photo # add NEW photo from cameraRoll
        return photo

    _getMomentHeight = (moment, index)->
      days = moment.value.length
      paddingTop = 10
      padding = 16+1
      h = days * (this.options.thumbnailSize+1) + padding * 2
      # console.log "i="+index+", moment.key="+moment.key+", h="+h
      return h  

    _getOverflowPhotos = (photos)->
      # console.log "\n\n_getOverflowPhotos  ** photo.length=" + photos.length+"\n"
      return count = Math.max(0, photos.length - this.options.thumbnailLimit )


    return {
      templateUrl: 'views/template/moment.html'
      restrict: 'EA'
      scope : 
        moments: '=otgModel'
      # replace: true
      # require: ''
      link: (scope, element, attrs) ->
        # element.text 'this is the moment directive'
        scope.options = _setSizes(element)
        scope.getAsPhotos = _getAsPhotos
        if _lookupPhoto==null
          _lookupPhoto = _.indexBy( otgData.parsePhotosFromMoments( cameraRoll.moments ), 'UUID')
        scope.getMomentHeight = _getMomentHeight
        scope.getOverflowPhotos = _getOverflowPhotos
        scope.otgWorkorder = otgWorkorder
        scope.ClassSelected = scope.$parent.ClassSelected
        return
      }
]
#
# otgMomentDateRange: a sample of thumbnails from workorder photos
#   only 1 date range, sample thumbnails, with end-caps
#   orderBy date DESC
#   grouped by consecutive days 
# used by app.order and app.workorders
#
.directive 'otgMomentDateRange', [
# renders moment as a dateRange, used in Orders or Workorders  
# adds an end-cap not found in otgMoment
  'otgData', 'cameraRoll'
  (otgData, cameraRoll)->

    options = defaults = {
      breakpoint: 480
      'col-xs': 
        rows: 2
        btnClass: ''
        thumbnailSize: 58-2
        thumbnailLimit: null # (w-69)/thumbnailSize
      'col-sm':
        rows: 2
        btnClass: 'btn-lg'
        thumbnailSize: 74-2
        thumbnailLimit: null # (w-88)/thumbnailSize
    }

    _setSizes = (element)->
      # also $window.on 'resize'  
      w = element[0].parentNode.clientWidth
      # console.log w
      if w < options.breakpoint
        cfg = _.clone options['col-xs']
        cfg.thumbnailLimit = (w-69)/cfg.thumbnailSize
      else # .btn-lg
        cfg = _.clone options['col-sm']
        cfg.thumbnailLimit = (w-88)/cfg.thumbnailSize

      whitespace = cfg.thumbnailLimit % 1
      # console.log "whitespace=" + whitespace + ", pixels=" +(whitespace * cfg.thumbnailSize)
      if whitespace * cfg.thumbnailSize < 28 
        # leave room for .badge
        cfg.thumbnailLimit -= 1
      cfg.thumbnailLimit = Math.floor(cfg.thumbnailLimit)  
      # use single row output if we have room
      if cfg.thumbnailLimit > 5
        cfg.rows = 1 
        cfg.thumbnailLimit -= 1

      # console.log "directive:otgMoment thumbnailLimit=" + cfg.thumbnailLimit
      return cfg

    ## @param moments either checkout.selectedMoments or workorderMoment
    summarize = (moments, options)->
      # sample photos from dateRange
      # moments sorted by mostRecent
      first = moments[moments.length-1]
      last = moments[0]
      summary = {
        key: last.key
        dateRange: {}
        type: 'summaryMoment'
        value: []
      }
      end = first.value[0]
      start = last.value[ last.value.length-1 ]
      summary.dateRange.from = start.key
      summary.dateRange.to = end.key
      # sample photos, as necessary
      length = options.rows * options.thumbnailLimit



      photos = otgData.parsePhotosFromMoments moments  # mostRecent first
      # orders have only 1 selectedMoment, unlike choose
      # TODO:  use reduce with dateRange instead




      photos.reverse() # sorted by date, mostRecent last
      if photos.length <= options.thumbnailLimit 
        # not enough photos for 2 rows
        summary.value.push photos
        options.rows = 1
      else if photos.length <= length
        # not enough photos to sample, use all photos
        summary.value.push photos.splice(0,options.thumbnailLimit)
        summary.value.push photos
      else 
        # sample photos
        incr =  photos.length / length
        sampled = []
        ( (i)->sampled.push( photos[ Math.floor(i) ])  )(i) for i in [0..photos.length-1] by incr

        sampled[sampled.length-1] = photos[photos.length-1]  # force LAST photo
        if options.rows == 2
          summary.value.push sampled.splice(0, options.thumbnailLimit)
        summary.value.push sampled

      # get updated values from cameraRoll.map()
      _.each summary.value[0], (o)->
        photo = _.find( cameraRoll.map(), {UUID: o.UUID})
        _.extend( o, photo) if photo  
        if o.from == 'PARSE' && o.src.indexOf('snaphappi.com') > -1
          parts = o.src.split('/')
          parts.push( '.thumbs/sq~' + parts.pop() )
          o.src = parts.join('/')
        return
      return summary

    self = {
      templateUrl:  'partials/otg-moment-date-range'
      restrict: 'EA'
      scope: 
        moments: '=otgModel'
      link: (scope, element, attrs)->
        scope.options = _setSizes(element)

        if scope.moments?.length
          scope.summaryMoment = summarize(scope.moments, scope.options) 
        return
    }
    return self
]

# incomplete - not properly implemented
# cache http URLs locally for workorders
.directive 'XXXimgCache', [ 'otgImgCache'
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



# ############################
# workorder directives. 
# ############################

# 
# apply ng-class for upload status indicators
#   CURRENTLY UNUSED. see $scope.watch.ngClass_uploadStatus() instead  
# 

.directive 'uploadStatus', [
  ()->
    return {
      restrict: 'A'
      link: (scope, element, attrs) ->
        scope.ngClass_UploadStatus =  (order, prefix='badge')->
          return if !order
          return prefix + '-balanced' if order.count_expected == (order.count_received + order.count_duplicate)
          return prefix + '-energized'

        scope.ngBind_UploadStatus = (order)->
          return 'unknown' if !order
          return 'ready' if order.count_expected == (order.count_received + order.count_duplicate)  
          return 'pending'
        return
    }
]

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