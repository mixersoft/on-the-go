'use strict'

###*
 # @ngdoc factory
 # @name onTheGo.snappiAssetsPicker
 # @description 
 # methods for accessing snappiAssetsPicker cordova plugin
 # 
###


angular
.module 'onTheGo.snappiAssetsPicker', []
.value 'PLUGIN_CAMERA_CONSTANTS', {
  DestinationType:
    DATA_URL: 0
    FILE_URI: 1
  EncodingType:
    JPEG: 0
    PNG: 1
  PictureSourceType:
    PHOTOLIBRARY: 0
    CAMERA: 1
    SAVEDPHOTOALBUM: 2
  MediaType:
    PICTURE: 0
    VIDEO: 1
    ALLMEDIA: 2
  PopoverArrowDirection:
    ARROW_UP: 1
    ARROW_DOWN: 2
    ARROW_LEFT: 4
    ARROW_RIGHT: 8
    ARROW_ANY: 15
}
.value 'assetsPickerCFG', {
  camera:
    quality:  85
    targetWidth: 640
    thumbnail: false
    correctOrientation: true
    destinationType: 0  # CAMERA.DestinationType.DATA_URL
  filesystem: 
    thumbnail: 'cacheDirectory'
    archive: 'dataDirectory' 
}
.factory 'appConsole', [
  '$ionicModal', '$q'
  ($ionicModal, $q)->

    self = {
      _modal: null
      _message: null
      log: (message)->
        self._message = message if _.isString message
        self._message = JSON.stringify message, null, 2 if _.isObject message
      show: (message)->
        self.log(message) if message
        return self._modal.show() if self._modal
        return _readyP.then ()->
          self._modal.show()
      hide: ()->
        self._modal?.hide()
        self._message = ''
      readyP: null
    }

    _readyP = $ionicModal.fromTemplateUrl 'partials/modal/console', {
        appConsole: self
        animation: 'slide-in-up'
      }
    .then (modal)->
        console.log "modal ready"
        self._modal = modal
      , (error)->
        console.log "Error: $ionicModal.fromTemplate"
        console.log error

    return self
]
.factory 'deviceReady', [
  '$q', '$timeout',  '$ionicPlatform'
  ($q, $timeout, $ionicPlatform)->
    _promise = null
    _timeout = 2000
    _device = null
    _isWebView = null
    _contentWidth = null 
    _deviceready = {
      deviceId: ()->
        return "browser" if !_deviceready.isWebView()
        return _device?.uuid

      isWebView: ()->
        return _isWebView

      contentWidth: (force)->
        return _contentWidth if _contentWidth && !force
        return _contentWidth = document.getElementsByTagName('ion-side-menu-content')[0]?.clientWidth
          
      waitP: ()->
        return _promise if _promise
        deferred = $q.defer()
        _cancel = $timeout ()->
            console.log "$ionicPlatform.ready NOT!!!"
            return deferred.reject("ERROR: ionicPlatform.ready does not respond")
          , _timeout
        $ionicPlatform.ready ()->
          $timeout.cancel _cancel
          # $rootScope.deviceId = $cordovaDevice.getUUID()
          _device = ionic.Platform.device()
          _isWebView = ionic.Platform.isWebView()
          console.log "$ionicPlatform reports deviceready, device.UUID=" + _deviceready.deviceId()
          return deferred.resolve("deviceready")
        return _promise = deferred.promise
    }
    return _deviceready
]
.factory 'cameraRoll', [
  '$q', '$timeout', '$rootScope', 'deviceReady', 
  'TEST_DATA', 'otgData'
  ($q, $timeout, $rootScope, deviceReady, TEST_DATA, otgData)->
    _getAsLocalTime = (d, asJSON=true)->
        d = new Date() if !d    # now
        d = new Date(d) if !_.isDate(d)
        throw "_getAsLocalTimeJSON: expecting a Date param" if !_.isDate(d)
        d.setHours(d.getHours() - d.getTimezoneOffset() / 60)
        return d.toJSON() if asJSON
        return d


    self = {
      _queue: {}  # array of DataURLs to fetch, use with debounce
      _mapAssetsLibrary: []  # stash in loadMomentsFromCameraRoll()
      # array of photos, use found = _.findWhere cameraRoll.photos, (UUID: uuid)
      # props: id->UUID, date, src, caption, rating, favorite, topPick, shared, exif
      #   plugin adds: dateTaken, origH, origW, height, width, crop, orientation,
      #   parse adds: assetId, from, createdAt, updatedAt
      photos: []
      dataURLs: {
        preview: {}     # indexBy UUID
        thumbnail: {}   # indexBy UUID
      }
      map: ()->
        return self._mapAssetsLibrary
      addPhoto: (photo)->
        # console.warn "\n\nERROR: photo.UUID 40 chars, iOS style, uuid=" + photo.UUID if photo.UUID.length > 36
        self.patchPhoto(photo)
        attrs =  _.omit photo, ['data', 'elapsed', 'format', 'crop', 'targetWidth', 'targetHeight']
        # self.photos.push attrs
        foundAt = _.findIndex self.photos, {UUID: attrs.UUID}
        # console.log "**** foundAt=" + foundAt + ", UUID: " + self.photos[foundAt].UUID + " == " + attrs.UUID if foundAt > -1
        if foundAt > -1  # update
          # console.log "\n\n *** addPhoto() updating photo found in cameraRoll.photos, UUID=" +attrs.UUID+ "\n\n"
          _.extend self.photos[foundAt], attrs
        else 
          insertAt = _.sortedIndex self.photos, attrs, 'dateTaken'
          self.photos.splice(insertAt, 0, attrs)
        # console.log "**** END addPhoto ****\n\n\n"  
        return attrs

      addDataURL: (size, photo)->
        # console.log "\n\n adding for size=" + size
        if !/preview|thumbnail/.test( size )
          return console.log "ERROR: invalid dataURL size, size=" + size
        console.log "WARNING: NOT truncating to UUID(36), UUID="+photo.UUID if photo.UUID.length > 36
        # console.log _.keys photo
        self.dataURLs[size][photo.UUID] = photo.data
        # console.log "\n\n added!! ************* " 
        return self

      # load moments, but not photos
      loadMomentsFromCameraRoll: (mapped)->
        ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
        if mapped
          self._mapAssetsLibrary = mapped 
        else 
          mapped = self._mapAssetsLibrary
        # cameraRoll._mapAssetsLibrary -> cameraRoll.moments
        photosByDate = otgData.mapDateTakenByDays(self._mapAssetsLibrary, "like TEST_DATA")
        # replace cameraRoll.moments
        justUUIDsByDate = {} # JUST [{date:[UUID,]},{}]
        _.each _.keys( photosByDate) , (key)->
          justUUIDsByDate[key] = _.map photosByDate[key], (o)->
            return o.UUID  # o.UUID[0...36]
        # console.log justUUIDsByDate
        self.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( justUUIDsByDate ), 2

        return self.moments

      # for testing only  
      patchPhoto: (photo)->
        # photo.topPick = true 
        photo.topPick = true if /^[AB]/.test(photo.UUID) 
        return

      getDateFromLocalTime : (dateTaken)->
        return null if !dateTaken
        if dateTaken.indexOf('+')>-1
          datetime = new Date(dateTaken) 
          # console.log "compare times: " + datetime + "==" +dateTaken
        else 
          # dateTaken contains no TZ info
          datetime = _getAsLocalTime(dateTaken, false) 

        datetime.setHours(0,0,0,0)
        date = _getAsLocalTime( datetime, true)
        return date.substring(0,10)  # like "2014-07-14"

      getDataURLP :  (UUID, size='preview')->
        found = self.getDataURL(UUID, size)
        return $q.when(found) if found
        # load from cameraRoll
        return snappiMessengerPluginService.getDataURLForAssets_P( [UUID], size )

      getDataURL: (UUID, size='preview')->
        if !/preview|thumbnail/.test size
          throw "ERROR: invalid dataURL size, size=" + size
        # console.log "$$$ camera.dataURLs lookup for UUID="+UUID+size
        # console.log self.dataURLs[size][UUID]
        found = self.dataURLs[size][UUID]
        if !found
          found = _.find self.dataURLs[size], (o,key)->
              return o if key[0...36] == UUID
        # console.log JSON.stringify {
        #   desc: "*** getDataURL ***"
        #   UUID: UUID
        #   size: size
        #   dataURL: found?[0...40]
        # }
        if !found # still not found, add to queue for fetch
          self.queueDataURL(UUID, size)
        return found

      # IMAGE_WIDTH should be computedWidth - 2 for borders
      getCollectionRepeatHeight : (photo, IMAGE_WIDTH)->
        if !IMAGE_WIDTH
          MAX_WIDTH = if deviceReady.isWebView() then 320 else 640
          IMAGE_WIDTH = Math.min(deviceReady.contentWidth()-22, MAX_WIDTH)
        if !photo.scaledH > 0
          if photo.originalWidth && photo.originalHeight
            aspectRatio = photo.originalHeight/photo.originalWidth 
            # console.log "index="+index+", UUID="+photo.UUID+", origW="+photo.originalWidth + " origH="+photo.originalHeight
            h = aspectRatio * IMAGE_WIDTH
          else # browser/TEST_DATA
            throw "ERROR: original photo dimensions are missing"
          photo.scaledW = IMAGE_WIDTH  
          photo.scaledH = h
          # console.log "index="+index+", scaledH="+h+" origH="+photo.originalHeight+", index.UUID="+cameraRoll.photos[index].UUID
        else 
          h = photo.scaledH
        return h

      queueDataURL : (UUID, size='preview')->
        return if !deviceReady.isWebView()
        self._queue[UUID] = { 
          UUID: UUID
          size: size, 
        }
        # debounce snappiMessengerPluginService.fetchDataURLsFromQueueP()
        $rootScope.$broadcast 'cameraRoll.queuedDataURL'
      queue: (clear)->
        self._queue = {} if clear=='clear'
        return _.clone self._queue


      getMomentPreviewAssets:(moments)->
        moments = self.moments if !moments
        # preload cameraRoll preview thumbnails
        previewPhotos = []
        PREVIEW_LIMIT = 5 # 5 thumbnails per moment/date
        IMAGE_FORMAT = 'thumbnail'
        _.each moments, (v,k,l)->
          if v['type'] == 'moment'
            _.each v['value'], (v2,k2,l2)->
              if v2['type'] == 'date'
                _.each v2['value'][0...PREVIEW_LIMIT], (UUID)->
                  # check if already loaded
                  if !(self.dataURLs[IMAGE_FORMAT]?[UUID]?)
                    # console.log "*** not yet loaded, UUID=" + UUID
                    previewPhotos.push {
                        UUID: UUID,
                        # date: v2['key']
                      }
        return previewPhotos

      # array of moments
      moments: []
      # orders
      orders: [] # order history
      state:
        photos:
          sort: null
          stale: false
    }

    deviceReady.waitP().then ()->
      if deviceReady.isWebView()
        # do NOT load TEST_DATA, wait for otgParse call by:
        # workorder: otgParse.fetchWorkorderPhotosByWoIdP()
        # top-picks: otgParse.fetchPhotosByOwnerP
        return
      else 
        # load TEST_DATA
        console.log "\n\n *** loading TEST_DATA ***\n\n"
        self.orders = TEST_DATA.orders
        photos_ByDateUUID = TEST_DATA.cameraRoll_byDate
        self.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( photos_ByDateUUID ), 2
        self.photos = otgData.parsePhotosFromMoments self.moments, 'TEST_DATA'

        return

    return self
]
.factory 'snappiMessengerPluginService', [
  '$rootScope', '$q', '$timeout', 'cameraRoll'
  'deviceReady', 'appConsole', 'otgData'
  ($rootScope, $q, $timeout, cameraRoll, deviceReady, appConsole, otgData)->

    # wrap $ionicPlatform ready in a promise, borrowed from otgParse   
    _MessengerPLUGIN = {
      MAX_PHOTOS: 200
      CHUNK_SIZE : 30
      SERIES_DELAY_MS: 100

      mapAssetsLibraryP: (options={})->
        console.log "mapAssetsLibrary() calling window.Messenger.mapAssetsLibrary(assets)"

        defaults = {
          # pluck: ['DateTimeOriginal', 'PixelXDimension', 'PixelYDimension', 'Orientation']
          fromDate: '2014-09-01'
          toDate: null
        }
        options = _.defaults options, defaults
        options.fromDate = cameraRoll.getDateFromLocalTime(options.fromDate) if _.isDate(options.fromDate)
        options.toDate = cameraRoll.getDateFromLocalTime(options.toDate) if _.isDate(options.toDate)

        return deviceReady.waitP().then (retval)->
          dfd = $q.defer()
          return $q.reject "ERROR: window.Messenger Plugin not available" if !(window.Messenger?.mapAssetsLibrary)
          console.log "about to call Messenger.mapAssetsLibrary(), Messenger.properties=" + JSON.stringify _.keys window.Messenger.prototype 
          window.Messenger.mapAssetsLibrary (mapped)->
              ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
              console.log "\n *** mapAssetsLibrary Got it!!! length=" + mapped.length
              return dfd.resolve ( mapped )
            , (error)->
              return dfd.reject("ERROR: MessengermapAssetsLibrary(), msg=" + JSON.stringify error)
          # console.log "called Messenger.mapAssetsLibrary(), waiting for callbacks..."
          return dfd.promise

      ##
      ## @param assets array [UUID,] or [{UUID:},{}]
      ##
      getDataURLForAssets_P: (assets, size)->
        # call getPhotosByIdP() with array
        return _MessengerPLUGIN.getPhotosByIdP( assets , size).then (photos)->
            console.log "\nDONE !!!!"
            _.each photos, (photo)->
              # merge into cameraRoll.dataUrls
              # keys:  UUID,data,elapsed, and more...
              # console.log "\n\n>>>>>>>  getPhotosByIdP(" + photo.UUID + "), DataURL[0..80]=" + photo.data[0..80]
              # cameraRoll.dataUrls[photo.format][ photo.UUID[0...36] ] = photo.data
              cameraRoll.addPhoto(photo)
              cameraRoll.addDataURL(photo.format, photo)
              console.log "\n*****************************\n"

            console.log "\n********** updated cameraRoll.dataURLs for this batch ***********\n"
            return photos
          , (errors)->
            console.log errors
            return $q.reject(errors)  # pass it on

      ##
      ## primary entrypoint for getting assets from an array of UUIDs
      ## @param assets array [UUID,] or [{UUID:},{}]
      ##
      getDataURLForAssetsByChunks_P : (tooManyAssets, size, delayMS=0)->
        if tooManyAssets.length < _MessengerPLUGIN.CHUNK_SIZE
          return _MessengerPLUGIN.getDataURLForAssets_P(tooManyAssets, size) 

        # load dataURLs for assets in chunks
        chunks = []
        chunkable = _.clone tooManyAssets
        chunks.push chunkable.splice(0, _MessengerPLUGIN.CHUNK_SIZE ) while chunkable.length
        console.log "\n ********** chunk count=" + chunks.length

        
        ## in Parallel, overloads device
        if !delayMS
          promises = []
          _.each chunks, (assets, i, l)->
            console.log "\n\n>>> chunk="+i+ " of length=" + assets.length
            promise = _MessengerPLUGIN.getDataURLForAssets_P( assets, size )
            promises.push(promise)
          return $q.all(promises).then (photos)->
              allPhotos = []
              # console.log photos
              _.each photos, (chunkOfPhotos, k)->
                allPhotos = allPhotos.concat( chunkOfPhotos )
              console.log "\n\n>>>  $q.all() done, dataURLs for all chunks retrieved!, length=" + allPhotos.length + "\n\n"
              return allPhotos
            , (errors)->
              console.error errors  

        allPhotos = []
        recurivePromise = (chunks, delayMS)->
          assets = chunks.shift()
          # all chunks fetched, exit recursion
          return $q.reject("done") if !assets
          # chunks remain, fetch chunk
          return _MessengerPLUGIN.getDataURLForAssets_P( assets , size).then (chunkOfPhotos)->
            return allPhotos if chunkOfPhotos=="done"
            allPhotos = allPhotos.concat( chunkOfPhotos ) # collate resolves into 1 array
            return chunkOfPhotos
          .then (o)->   # delay between recursive call
            dfd = $q.defer()
            $timeout ()->
              # console.log "\n\ntimeout fired!!! remaining="+chunks.length+"\n\n"
              dfd.resolve(o)
            , delayMS || _MessengerPLUGIN.SERIES_DELAY_MS
            return dfd.promise 
          .then (o)->
              # call recurively AFTER delay
              return recurivePromise(chunks)

        return recurivePromise(chunks, 500).catch (error)->
          return $q.when(allPhotos) if error == 'done'
          return $q.reject(error)
        .then (allPhotos)->
          console.log "\n\n>>>  SERIES fetch done, dataURLs for all chunks retrieved!, length=" + allPhotos.length + "\n\n"
          return allPhotos

      ##
      ## @param assets array [UUID,] or [{UUID:},{}]
      ##
      getPhotosByIdP: (assets, size='preview')->
        return $q.when([]) if _.isEmpty assets
        # takes asset OR array of assets
        options = {type: size} 

        defaults = {
          preview: 
            targetWidth: 640
            targetHeight: 640
            resizeMode: 'aspectFit'
            autoRotate: true
          previewHD: 
            targetWidth: 1080
            targetHeight: 1080
            resizeMode: 'aspectFit'
            autoRotate: true
          thumbnail:
            targetWidth: 64
            targetHeight: 64
            resizeMode: 'aspectFill'
            autoRotate: true
        }
        options = _.extend options, defaults.preview if options.type=="preview"
        options = _.extend options, defaults.thumbnail if options.type=="thumbnail"
        options = _.extend options, defaults.previewHD if options.type=="previewHD"
        
        assets = [assets] if !_.isArray(assets)
        assetIds = assets
        assetIds = _.pluck assetIds, 'UUID' if assetIds[0].UUID
        

        # console.log "\n>>>>>>>>> getPhotosByIdP: assetIds=" + JSON.stringify assetIds 
        # console.log "\n>>>>>>>>> getPhotosByIdP: options=" + JSON.stringify options

        deviceReady.waitP().then (retval)->
          dfd = $q.defer()
          start = new Date().getTime()
          return $q.reject "ERROR: window.Messenger Plugin not available" if !(window.Messenger?.getPhotoById)
          remaining = assetIds.length
          retval = {
            photos: []
            errors: []
          }

          # similar to $q.all()
          _resolveIfDone = (remaining, retval, dfd)->
            # console.log "***  _resolveIfDone ****, remaining=" + remaining
            return if remaining
            if retval.errors.length == 0
              console.log "\n>>>>>>>> window.Messenger.getPhotoById()  complete, count=" + retval.photos.length + " \n\n"
              return dfd.resolve ( retval.photos ) 
            else if retval.photos.length && retval.errors.length 
              console.log "WARNING: SOME errors occurred in Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
              return dfd.resolve ( retval.photos ) 
            else if retval.errors.length 
              return dfd.reject "ERROR: Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors


          window.Messenger.getPhotoById assetIds, options, (photo)->
              # dupe = _.clone photo
              # dupe.data = dupe.data[0..40]
              # console.log dupe

              # one callback for each element in assetIds
              end = new Date().getTime()
              # photo keys: [data,UUID,dateTaken,originalWidth,originalHeight]
              photo.elapsed = (end-start)/1000
              photo.from = 'cameraRoll'
              photo.date = cameraRoll.getDateFromLocalTime(photo.dateTaken)
              photo.autoRotate = options.autoRotate
              photo.orientation = 'unknown'    # missing
              if (photo.autoRotate)
                # originalHeight/Width is not swapping
                console.log "\n\n Messenger Plugin.getPhotosByIdP(): WARNING originalH/W not swapping on autoRotate"


              # plugin method options              
              photo.format = options.type  # thumbnail, preview, previewHD
              photo.crop = options.resizeMode == 'aspectFill'
              photo.targetWidth = options.targetWidth
              photo.targetHeight = options.targetHeight
              
              console.log "*** window.Messenger.getPhotoById success!! *** elapsed=" + (end-start)/1000

              retval.photos.push photo
              remaining--
              return _resolveIfDone(remaining, retval, dfd)
            , (error)->
              retval.errors.push error
              remaining--
              return _resolveIfDone(remaining, retval, dfd)

          return dfd.promise

      fetchDataURLsFromQueue : _.debounce ()->
          # ???: can you debounce a promise???
          queuedAssets = cameraRoll.queue()
          cameraRoll.queue('clear')
          chunks = {}
          _.each ['preview', 'thumbnail'], (size)->
            assets = _.filter queuedAssets, (o)->return o.size == size
            chunks[size] = assets if assets.length
          
          promises = []
          _.each chunks, (assets, size)->
            console.log "\n\n *** fetchDataURLsFromQueueP START! size=" + size + ", count=" + assets.length + "\n"
            promises.push _MessengerPLUGIN.getDataURLForAssetsByChunks_P(assets, size).then (photos)->
              # update images with dataURLs by UUID
              imageEls = document.getElementsByTagName('IMG')
              imageLookup = _.indexBy imageEls, (img)->return img.getAttribute('uuid') + "-" + img.getAttribute('format')
              dataURLLookup = _.indexBy photos, 'UUID'

              _.each dataURLLookup, (photo, uuid)->
                # console.log "\n\n *** fetchDataURLsFromQueueP: searching for UUID-size="+ photo.UUID + '-' + photo.format
                imageKey =  photo.UUID[0...36] + '-' + photo.format 
                if imageLookup[ imageKey ]?
                  imageLookup[ imageKey ].src = dataURLLookup[photo.UUID].data 
                  console.log "\n\n *** fetchDataURLsFromQueueP: updating img.src! UUID-size=" + imageKey
              return photos


          return $q.all(promises).then (o)->
            console.log "\n\n *** fetchDataURLsFromQueueP $q All Done! \n"
        , 500

    }
    return _MessengerPLUGIN
]

