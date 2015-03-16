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
  'deviceReady', 'PLUGIN_CAMERA_CONSTANTS', 'cameraRoll', 'imageCacheSvc', '$rootScope', '$q'
  (deviceReady, CAMERA, cameraRoll, imageCacheSvc, $rootScope, $q)->

    _getAsSnappiSqThumb = (src='')->
      return src if src.indexOf('snaphappi.com/svc') == -1  # autoRender not available
      parts = src.split('/')
      return src if parts[parts.length-1].indexOf('sq~') == 0 # already an sq~ URL
      parts.push( '.thumbs/sq~' + parts.pop() )
      return parts.join('/')

    collectionRepeatDataURLS = {}

    _setLazySrc = (element, UUID, format)->
      throw "ERROR: asset is missing UUID" if !UUID
      IMAGE_SIZE = format || 'thumbnail'

      # priorities: stashed FileURL > cameraRoll.dataURL > photo.src
      scope = element.scope()
      photo = scope.item || scope.photo  # TODO: refactor in TopPicks, use scope.photo

      isWorkorder = $rootScope.isStateWorkorder() 
      isOrder = $rootScope.$state.includes('app.orders')
      isMoment = IMAGE_SIZE=='thumbnail' && (isWorkorder || isOrder)
      isBrowser = !isDevice =  deviceReady.device().isDevice

      if isDevice 
        # get updated values from cameraRoll.map()
        mappedPhoto = _.find( cameraRoll.map(), {UUID: photo.UUID})
        _.extend( photo, mappedPhoto) if mappedPhoto

      if isDevice && IMAGE_SIZE=='preview' && previewDataURL = collectionRepeatDataURLS[photo.UUID]
        console.log "using dataURL for collection-repeat"
        return element.attr('src', previewDataURL) 



      if isMoment && isOrder
        if isOrder && photo.src?.indexOf('file:') == 0
          return element.attr('src', photo.src)
        else
          thumbSrc = _getAsSnappiSqThumb(photo.src)
          element.attr('src', thumbSrc)
          isLocal = (photo.deviceId == $rootScope.device.id)
          return if !isLocal
        # else continue to bottom to check isStashed


      if isMoment && isWorkorder # try to use /sq~ images from autoRender
        thumbSrc = _getAsSnappiSqThumb(photo.src || photo.woSrc)
        return element.attr('src', thumbSrc)


      if isWorkorder # preview
        return element.attr('src', photo.src || photo.woSrc) 

      if isBrowser && photo.from == 'PARSE' 
        # user sign-in viewing topPicks from browser
        return element.attr('src', photo.src) 

      # return if isBrowser && !photo # digest cycle not ready yet  
      if !isWorkorder && isBrowser && window.TEST_DATA # DEMO mode
        return _useLoremPixel(element, UUID, format)

      promise = imageCacheSvc.isStashed_P(UUID, format)
      # promise = $q.reject("force DestinationType='DATA_URL' for collection-repeat")
      .then (stashed)->
        element.attr('src', stashed.fileURL)
        return
      .catch (error)->
        # console.log "\nlazySrc reports notCached for format=" + format + ", UUID="+UUID
        if isBrowser
          throw "_setLazySrc() img.src not found for isBrowser==true and " + [UUID, format].join(':')

        # isDevice so check CameraRoll with promise
        options = {
          size: IMAGE_SIZE
          DestinationType : CAMERA.DestinationType.FILE_URI 
        }
        # options.DestinationType = CAMERA.DestinationType.DATA_URL if IMAGE_SIZE=='preview'
        return cameraRoll.getPhoto_P( UUID, options )
        .then (resp)->
          if options.DestinationType == CAMERA.DestinationType.FILE_URI
            imageCacheSvc.stashFile(UUID, IMAGE_SIZE, resp.data, resp.dataSize) # FILE_URI
          else if options.DestinationType == CAMERA.DestinationType.DATA_URL && IMAGE_SIZE == 'preview'
            "do NOT cache DATA_URL" || imageCacheSvc.cordovaFile_USE_CACHED_P(element, resp.UUID, resp.data) 
            collectionRepeatDataURLS[resp.UUID] = resp.data
          else 
            'not caching DATA_URL thumbnails'

          if element.attr('lazy-src') != resp.UUID
            throw '_setLazySrc(): collection-repeat changed IMG[lazySrc] before cameraRoll image returned'
          else 
            element.attr('src', resp.data)
          return
      .catch (error)->
        return console.warn "_setLazySrc():", error
      return
        

    _useLoremPixel = (element, UUID, format)->
      console.error "ERROR: using lorempixel from device" if deviceReady.device().isDevice
      scope = element.scope()
      switch format
        when 'thumbnail'
          options = scope.options  # set by otgMoment`
          src = TEST_DATA.lorempixel.getSrc(UUID, options.thumbnailSize, options.thumbnailSize)
        when 'preview'
          src = scope.item?.src
          src = TEST_DATA.lorempixel.getSrc(UUID, scope.item.originalWidth, scope.item.originalHeight) if !src
      return element.attr('src', src)  # use ng-src here???


    return {
      restrict: 'A'
      scope: false
      link: (scope, element, attrs) ->
        format = attrs.format

        attrs.$observe 'lazySrc', (UUID)->
          # console.log "\n\n $$$ attrs.$observe 'lazySrc', UUID+" + UUID
          element.attr('uuid', UUID)
          src = _setLazySrc(element, UUID, format) 
          console.error "ERROR: using lazySrc BEFORE deviceReady.waitP()" if deviceReady.device().isDevice==null
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
      return 0 if !moment
      days = moment.value.length
      paddingTop = 10
      padding = 16+1
      padding += 20 # .moment-label
      h = days * (this.options.thumbnailSize+1) + padding * 2
      # console.log "i="+index+", moment.key="+moment.key+", h="+h
      return h  

    _getMomentLabel = (moment)->
      label = cameraRoll.iOSCollections.getLabelForDates(_.pluck( moment.value, 'key'))
      return label.labels.concat(label.locations).join(', ')    

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
        if _lookupPhoto==null
          _lookupPhoto = _.indexBy( otgData.parsePhotosFromMoments( cameraRoll.moments, cameraRoll.map() ), 'UUID')
        _.extend scope, {
          getAsPhotos: _getAsPhotos
          getOverflowPhotos :_getOverflowPhotos
          getMomentHeight: _getMomentHeight
          getMomentLabel: _getMomentLabel          
          otgWorkorder: otgWorkorder
          ClassSelected: scope.$parent.ClassSelected
        }
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



      photos = otgData.parsePhotosFromMoments moments, cameraRoll.map()  # mostRecent first
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

      return summary

    self = {
      templateUrl:  'views/partials/otg-moment-date-range.html'
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
# apply ng-bind & ng-class for workorder status indicators 
# 

.directive 'workorderStatus', [
  ()->
    return {
      restrict: 'A'
      link: (scope, element, attrs) ->
        THRESHOLD = {
          WORKING: 0.9
          COMPLETE: 0.9
        }
        scope.ngClass_WorkStatus = (order, prefix='badge')->
          return if !order
          return prefix + '-energized' if /^(new|rejected)/.test order.status
          return prefix + '-balanced' if /^(ready|working)/.test order.status
          return prefix + '-positive' if order.status == 'complete' 
          return prefix + '-royal' if order.status == 'closed'     
        scope.ngClass_CompleteButton = (order, prefix='badge')->
          return if !order
          isAlmostDone = (1 - order.progress.todo/order.count_expected) > THRESHOLD.COMPLETE
          return prefix + '-balanced' if isAlmostDone && order.status=='working'
          return prefix + '-energized disabled' 
        scope.ngClass_UploadStatus = (order, prefix='badge')->
          return if !order
          return prefix + '-balanced' if order.count_expected == (order.count_received + order.count_duplicate)
          return prefix + '-energized'
        scope.ngBind_UploadStatus = (order)->
          return if !order
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
      templateUrl: 'views/partials/workorders/menu-workorder-snapshot.html'
      restrict: 'EA'
      scope:{
        order:'=ngModel'
      }
      link: (scope, element, attrs)->
        return
    }
    return self
]