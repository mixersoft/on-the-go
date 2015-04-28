'use strict'

###*
 # @ngdoc directive
 # @name onTheGoApp.service:directives
 # @description
 # # directives
###


### 
# directive: lazy-src
# load img.src from the following sources, in order of priority
#   imgCacheSvc (browser/WebView FileURL)
#   cameraRoll.dataURL[] (dataURL, FileURL or parse URL)
#   lorempixel (for brower debug)
# 
# uses $q.promise to load src from promise if not immediately available
#
# attributes: 
#   lazySrc: UUID of photo, used to fetch img.src
#   spinner: add ion loading-c spinner, show during img.load
#   format: [thumbnail, preview]
# 
###
angular.module('ionBlankApp') 
.directive 'lazySrc', [
  'deviceReady', 'PLUGIN_CAMERA_CONSTANTS', 'cameraRoll', 'imageCacheSvc', '$rootScope', '$q', '$parse'
  (deviceReady, CAMERA, cameraRoll, imageCacheSvc, $rootScope, $q, $parse)->

    _getAsSnappiSqThumb = (src='')->
      return src if src.indexOf('snaphappi.com/svc') == -1  # autoRender not available
      parts = src.split('/')
      return src if parts[parts.length-1].indexOf('sq~') == 0 # already an sq~ URL
      parts.push( '.thumbs/sq~' + parts.pop() )
      return parts.join('/')

    _setLazySrc = (element, UUID, format)->
      # console.log '\nsetLazySrc for UUID='+UUID
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


      if isMoment && isOrder
        if isOrder && photo.src?.indexOf('file:') == 0
          return photo.src # element.attr('src', src)
        else if isRemote = (photo.deviceId != $rootScope.device.id)
          thumbSrc = _getAsSnappiSqThumb(photo.src)
          return thumbSrc # element.attr('src', thumbSrc)
        # else continue to bottom to get local img


      if isMoment && isWorkorder # try to use /sq~ images from autoRender
        thumbSrc = _getAsSnappiSqThumb(photo.src || photo.woSrc)
        return thumbSrc # element.attr('src', thumbSrc)


      # TODO: confirm photo.from=='PARSE' are all photos from not in CameraRoll
      # what about cameraRoll phtoos with an OLD deviceId?
      if isWorkorder || photo.from=='PARSE' # preview
        return photo.src || photo.woSrc # element.attr('src', photo.src || photo.woSrc) 

      if isBrowser && photo.from == 'PARSE' 
        # user sign-in viewing topPicks from browser
        return photo.src # element.attr('src', photo.src) 

      # return if isBrowser && !photo # digest cycle not ready yet  
      if !isWorkorder && isBrowser && window.TEST_DATA # DEMO mode
        return _useLoremPixel(element, UUID, format)

      ##
      #
      # NOTE: src values AFTER this point are retrieved async, update element directly
      #
      ##
      promise = imageCacheSvc.isStashed_P(UUID, format)
      # promise = $q.reject("force DestinationType='DATA_URL' for collection-repeat")
      .then (stashed)->
        element.attr('src', stashed.fileURL)
        return 
      .catch (error)->
        # console.log "lazySrc notCached for format=" + format + ", UUID="+UUID
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
            imageCacheSvc.cordovaFile_USE_CACHED_P(element, resp.UUID, resp.data) 
          else 
            'not caching DATA_URL thumbnails'

          if element.attr('lazy-src') != resp.UUID
            throw '_setLazySrc(): collection-repeat changed IMG[lazySrc] before cameraRoll image returned'
          else 
            element.attr('src', resp.data) 
          return
      .catch (error)->
        console.warn "_setLazySrc():", error
        return 
      return null
        

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
      return src # element.attr('src', src) 

    # from onImgLoad attrs.spinner
    _spinnerMarkup = '<i class="icon ion-load-c ion-spin light"></i>'
    _clearGif = 'img/clear.gif'  
    _handleLoad = (ev)->
      $elem = angular.element(ev.currentTarget)
      if $elem.attr('src') == _clearGif
        UUID = $elem.attr('lazy-src')
        # console.log "img.src=clearGif error, UUID="+UUID
        return 
      $elem.removeClass('loading')
      $elem.next().addClass('hide')  if $elem.attr('spinner')?
      onImgLoad = $elem.attr('on-photo-load')
      if onImgLoad?
        fn = $parse(onImgLoad) 
        scope = $elem.scope()
        scope.$apply ()->
          fn scope, {$event: ev}
          return
      return

    _handleError = (ev)->
      $elem = angular.element(ev.currentTarget)
      UUID = $elem.attr('lazy-src')
      console.error "img.onerror, UUID="+UUID+", src="+ev.currentTarget.src[-30..]
      return


    return {
      restrict: 'A'
      scope: false
      link: (scope, element, attrs) ->
        format = attrs.format

        attrs.$observe 'lazySrc', (UUID)->
          if deviceReady.device().isDevice==null
            console.error "ERROR: using lazySrc BEFORE deviceReady.waitP()" 
            return 
          if !UUID
            console.log "$$$ attrs.$observe 'lazySrc', UUID+" + UUID
            return 
          # element.attr('uuid', UUID)
          src = _setLazySrc(element, UUID, format)
          # element.attr('src', _clearGif) if !src
          element.attr('src', src) if src
          element.addClass('loading')
          element.next().removeClass('hide') if element.attr('spinner')?
          return src

        element.on 'load', _handleLoad
        # element.on 'error', _handleError
        scope.$on 'destroy', ()->
          element.off _handleLoad
          element.off _handleError
          return
        element.after(_spinnerMarkup) if attrs.spinner?
        return
  }
]


.directive 'onImgLoad', ['$parse' , ($parse)->
  # add ion-animation.scss
  spinnerMarkup = '<i class="icon ion-load-c ion-spin light"></i>'
  _clearGif = 'img/clear.gif'
  _handleLoad = (ev, photo, index)->
    $elem = angular.element(ev.currentTarget)
    $elem.removeClass('loading')
    $elem.next().addClass('hide')
    onImgLoad = $elem.attr('on-photo-load')
    fn = $parse(onImgLoad)
    scope = $elem.scope()
    scope.$apply ()->
      fn scope, {$event: ev}
      return
    return
  _handleError = (ev)->
    console.error "img.onerror, src="+ev.currentTarget.src


  return {
    restrict: 'A'
    link: (scope, $elem, attrs)->


      # NOTE: using collection-repeat="item in items"
      attrs.$observe 'ng-src', ()->
        $elem.addClass('loading')
        $elem.next().removeClass('hide')
        return

      $elem.on 'load', _handleLoad
      $elem.on 'error', _handleError
      scope.$on 'destroy', ()->
        $elem.off _handleLoad
        $elem.off _handleError
      $elem.after(spinnerMarkup)
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

.directive 'notify', ['notifyService'
  (notifyService)->
    return {
      restrict: 'A'
      scope: true
      templateUrl: 'views/template/notify.html'
      link: (scope, element, attrs)->
        scope.notify = notifyService

        if notifyService._cfg.debug
          window.debug.notify = notifyService        
        return
    }

]


.directive 'shotGroupProgress', [
  '$compile'
  ($compile)->
    controller = {
      shot: 
        position: 0 # position in items
        id: null
        index: null
        count: 0
      getShotId : (item)->
        return null if !item
        return item.burstIdentifer || item.dateTaken  # sue a proxy for shotId

      getShot : (index, items, isFirst)->
        # NOTE: assumes items are sorted by shotId
        count = 0
        shotId = controller.getShotId( items[ index ] )
        loop
          count+=1
          item = items[ index + count ]
          break if shotId != controller.getShotId( item )
        shot = {
          position: index
          id: shotId
          index: 0
          count: count
        }  
        if !isFirst && index > 0
          count = 1
          loop
            count-=1
            item = items[ index + count - 1 ]
            break if shotId != controller.getShotId( item )
          if count
            count = -1 * count
            shot.index += count
            shot.count += count
            shot.position = index - count
        return shot

      updateIndex : (cur, prev, items)->
        shotId = controller.getShotId(items[cur])
        curShot = controller.shot
        if curShot.id == shotId
          curShot.index = cur - curShot.position
        else
          isFirst = (prev == cur - 1) && prev > 0
          shot = controller.getShot( cur, items, isFirst )
          _.extend curShot, shot
        return curShot

      renderShot : ($parent, shot)->
        if false && $parent.attr('shot-id') == shot.id
          # update index
          $shotItems = $parent.children()
          $shotItems.removeClass('selected')
          angular.element($shotItems[shot.index]).addClass('selected')
          
        else
          $parent.html('').attr('shot-id', shot.id)
          return $parent if shot.count<=1

          console.log "shot=", shot
          for i in [0...shot.count] by 1
            console.log "> shot-item, index=", i
            $oneEl = angular.element markup.item
            $oneEl.addClass('selected') if i == shot.index
            $parent.append($oneEl)
        return $parent

    }

    markup = {
      item: '<div class="shot-item"></div>'
    }

    self = {
      restrict: 'A'
      scope: {
        items: '=shotGroupProgress'
        index: '='
        doAction: '&'
      }
      link: (scope, $elem, attrs)->
        scope.itemClick = (ev)->
          action = ev.currentTarget.getAttribute('action')
          console.log "button clicked, action=", action
          scope.doAction({action:action, workorder:scope.wo})
          return

        scope.$watch 'index', (newV, oldV)->
          return if `newV==null`
          shot = controller.updateIndex(newV, oldV, scope.items)
          controller.renderShot($elem, shot)
          return 

        $elem.addClass('shot-group-progress')
        
        # return $compile( $elem.contents())(scope)
        return
    }
    return self    


]

# ############################
# workorder directives. 
# ############################

# 
# apply ng-bind & ng-class for workorder status indicators 
#   used by menu:badge and order-card, 
#   NOTE: workorder-photos uses workorderActions bar intead
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

.directive 'workorderActions', ['$compile'
  ($compile)->
    THRESHOLD = {
      WORKING: 0.9
      COMPLETE: 0.9
    }

    colors = {
      action:
        'open': (wo)->
          return 'assertive' if wo.status=='closed'
          return 'balanced' if wo.count_expected == (wo.count_received + wo.count_duplicate)
          return 'energized'
        'complete': (wo)->
          isAlmostDone = (1 - wo.progress.todo/wo.count_expected) > THRESHOLD.COMPLETE
          return 'balanced' if isAlmostDone && wo.status=='working'
          return 'energized disabled' 
        'review': 'positive'
        'close': 'royal'
        'reject': 'assertive'
    }

    markup = {
      bar: '<div class="button-bar"></div>'
      button: '<button class="button button-full capitalize" ng-click="buttonClick($event)" action=""></button>'
    }

    self = {
      restrict: 'A'
      scope: {
        wo: '=model'
        doAction: '&'
      }
      link: (scope, $elem, attrs)->
        scope.buttonClick = (ev)->
          action = ev.currentTarget.getAttribute('action')
          console.log "button clicked, action=", action
          scope.doAction({action:action, workorder:scope.wo})
          return
          

        switch scope.wo.status
          when 'new', 'ready', 'working'
            actions = ['open', 'complete']
          when 'complete'
            actions = ['review', 'close', 'reject']
          when 'closed'
            actions = ['review', 'open']

        $bar = angular.element markup.bar
        _.each actions, (action)->
          button = angular.element markup.button
          color = colors.action[action]
          color = color(scope.wo) if _.isFunction color
          button.html(action).addClass( 'button-'+color )
            .attr('action', action)
          $bar.append( button)
          return
        $elem.append $bar
        return $compile( $elem.contents())(scope)
    }
    return self
]

