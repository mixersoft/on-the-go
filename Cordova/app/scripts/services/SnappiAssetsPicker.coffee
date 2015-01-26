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
  '$q', '$timeout', '$rootScope', 'deviceReady', 'snappiMessengerPluginService', 'imageCacheSvc'
  'TEST_DATA', 'otgData', 'appConsole'
  ($q, $timeout, $rootScope, deviceReady, snappiMessengerPluginService, imageCacheSvc, TEST_DATA, otgData, appConsole)->
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
      readyP: ()->
        return 

      map: ()->
        return self._mapAssetsLibrary

      getPhoto: (UUID)->
        # find the photo, if we have it
        found = _.find self.photos, { UUID: UUID } 
        # get from cameraRoll.map() if not in cameraRoll.photo
        if !found
          found = _.find self.map(), { UUID: UUID } 
          cameraRoll.getDataURL UUID, 'thumbnail' # queue to add to cameraRoll.photos

        return found if found
        console.error '\n\nERROR: cameraRoll.getPhoto(): is not found, UUID=' + UUID 
        return null


      loadCameraRollP: (options)->
        defaults = {
          size: 'thumbnail'
          # pluck: ['favorite','mediaType', 'mediaSubTypes', 'hidden']  
          # fromDate: null
          # toDate: null
        }
        options = _.defaults options, defaults
        # options.fromDate = self.getDateFromLocalTime(options.fromDate) if _.isDate(options.fromDate)
        # options.toDate = self.getDateFromLocalTime(options.toDate) if _.isDate(options.toDate)

        start = new Date().getTime()
        return snappiMessengerPluginService.mapAssetsLibraryP(options)
        .then ( mapped )->
          if _.isEmpty self._mapAssetsLibrary
            self._mapAssetsLibrary = mapped 
          else 
            # NOTE: this will reflect deletions if we don't merge
            self._mapAssetsLibrary = mapped 
          return mapped

        .then (mapped)->
          promise = self.loadFavoritesP(5000)
          # don't wait for promise
          return mapped

        .then ( mapped )->

          end = new Date().getTime()
          console.log "\n*** mapAssetsLibraryP() complete, elapsed=" + (end-start)/1000
          moments = self.loadMomentsFromCameraRoll( mapped ) # mapped -> moments
          # camraRoll ready

          if false && "appConsole"
            retval = {
              title: "*** snappiMessengerPluginService.mapAssetsLibraryP() ***"
              elapsed : (end-start)/1000
              'moment[0].value' : moments[0].value
              'mapped[0..10]': mapped[0..10]
            }
            appConsole.show( retval )

          return mapped
        .then (mapped)->
          promise = self.loadMomentThumbnailsP(5000)
          # don't wait for promise
          return mapped

        .catch (error)->
          console.log error
          # appConsole.show( error)
          return $q.reject(error)

      loadFavoritesP: (delay=10)->
        # load 'preview' of favorites from cameraRoll, from mapAssetsLibrary()
        favorites = _.filter self.map(), {favorite: true}
        # check against imageCacheSvc
        notCached = _.reduce( 
          favorites
          , (result, photo)->
            result.push photo.UUID if !imageCacheSvc.isStashed( photo.UUID, 'preview')
            return result
          , []
        )
        console.log "\n\n\n*** preloading favorite previews for UUIDs: " 
        # console.log notCached
        return self.loadPhotosP(notCached, delay)

      loadMomentThumbnailsP: (delay=10)->
        # preload thumbnail DataURLs for self moment previews
        momentPreviewAssets = self.getMomentPreviewAssets() # do this async
        # check against imageCacheSvc
        notCached = _.reduce( 
          momentPreviewAssets
          , (result, photo)->
            result.push photo.UUID if !imageCacheSvc.isStashed( photo.UUID, 'thumbnail')
            return result
          , []
        )
        console.log "\n\n\n*** preloading moment thumbnails for UUIDs: " 
        # console.log notCached
        return self.loadPhotosP(notCached, delay)


      loadPhotosP: (photos, delay=10)->
        dfd = $q.defer()
        _fn = ()->
            start = new Date().getTime()
            return snappiMessengerPluginService.getDataURLForAssetsByChunks_P( 
              photos
              , 'thumbnail'                          
              , self.patchPhoto
              , snappiMessengerPluginService.SERIES_DELAY_MS 
            )
            .then ()->
              end = new Date().getTime()
              console.log "\n*** thumbnail preload complete, elapsed=" + (end-start)/1000
              dfd.resolve('success')
            .then ()->
              return
              # show results in AppConsole
              if false && "appConsole"
                truncated = {
                  "desc": "cameraRoll.dataURLs"
                  photos: cameraRoll.photos[0..TEST_LIMIT]
                  dataURLs: {}
                }
                if deviceReady.isWebView()
                  _.each cameraRoll.dataURLs[IMAGE_FORMAT], (dataURL,uuid)->
                    truncated.dataURLs[uuid] = dataURL[0...40]
                else 
                  _.each photos, (v,k)->
                    truncated.dataURLs[v.UUID] = v.data[0...40]
                # console.log truncated # $$$
                $scope.appConsole.show( truncated )
                return photos 
        $timeout ()-> 
            _fn()     
          , delay  
        return dfd.promise   

      clearPhotos_PARSE : ()->
        # on logout
        self.photos = _.filter self.photos, (photo)->
            return photo.from != 'PARSE'

      # standard eachPhoto callback
      patchPhotoFromMap: (photo)->
        foundInMap = _.find self._mapAssetsLibrary, {UUID: photo.UUID}
        _.extend photo, _.pick foundInMap, ['favorite','mediaType', 'mediaSubTypes', 'hidden']  

      patchPhoto: (photo)->

        # photo.topPick = true 
        # photo.topPick = true if /^[AB]/.test(photo.UUID) 

        # otgParse._patchParsePhotos(): patched attrs will be saved back to PARSE
        # cameraRoll.patchPhoto(): will just patch local attrs
        # ???: where do we want to patch photo.from???
        photo.date = self.getDateFromLocalTime(photo.dateTaken)
        self.patchPhotoFromMap( photo )
        # NOTE: originalWidth, originalHeight properties may not adjust for autoRotate
        if photo.from == 'PARSE'
          if photo.src == 'Base64 encoding failed'
            photo.src = ''
            photo.isInvalid = true
            photo.originalHeight = 100
            photo.originalWidth = 640

        # commit patch    
        self._addOrUpdatePhoto_FromCameraRoll(photo)

        # add to dataURLs
        if photo.from == 'PARSE'
          # add src directly
          self.dataURLs['preview'][photo.UUID] = photo.src
          "NOTE: use imgCache.js to cache PARSE URLs"

        else
          self.addDataURL(photo.format, photo)    
        return

      _addOrUpdatePhoto_FromCameraRoll: (photo)->

        # note = "called by getDataURLForAssets_P, which assumes UUID in map, but not in photos"
        # note = "   includes cameraRoll attrs from Messenger Plugin"

        # console.warn "\n\nERROR: photo.UUID 40 chars, iOS style, uuid=" + photo.UUID if photo.UUID.length > 36
        attrs =  _.omit photo, ['data', 'elapsed', 'format', 'crop', 'targetWidth', 'targetHeight', 'assetId']
        # self.photos.push attrs
        foundAt = _.findIndex self.photos, {UUID: attrs.UUID}
        # console.log "**** foundAt=" + foundAt + ", UUID: " + self.photos[foundAt].UUID + " == " + attrs.UUID if foundAt > -1
        if foundAt > -1  # update
          # console.log "\n\n *** _addOrUpdatePhoto_FromCameraRoll() updating photo found in cameraRoll.photos, UUID=" +attrs.UUID+ "\n\n"
          _.extend self.photos[foundAt], attrs
        else 
          insertAt = _.sortedIndex self.photos, attrs, 'dateTaken'
          self.photos.splice(insertAt, 0, attrs)

        # console.log "**** END _addOrUpdatePhoto_FromCameraRoll ****\n\n\n"  
        return attrs


      addOrUpdatePhoto_FromWorkorder: (photo)->
        # typically called from Editor Workstation in Browser, in this case, there is no local CameraRoll
        # called from otgWorkorderSync._patchParsePhotos() after patching with ParseObj attrs

        # cameraRoll.getDataURL only works if UID in map()
        # foundInMap = _.find cameraRoll._mapAssetsLibrary, (o)->return o.UUID[0...36] == photo.UUID[0...36]


        foundInMap = _.find self._mapAssetsLibrary, {UUID: photo.UUID}
        if !foundInMap 
          # WARNING: UUID might still be in cameraRoll, but not cached
          # photo.topPick = !!photo.topPick
          self._mapAssetsLibrary.push _.pick photo, ['UUID', 'dateTaken', 'from']
          # if its not in map() it cannot be in photos, so add
          self.patchPhoto photo
          

          # add to DataURLs, as necessary
          exists = self.dataURLs['preview'][photo.UUID]
          if exists && self.isDataURL(exists)
            # keep dataURL or replace with remote parsefile?
          else if photo.src
            self.dataURLs['preview'][photo.UUID] = photo.src 
          # console.log "\n**** NEW photo from WORKORDER added to map() & photos, uuid=" + photo.UUID
          return  



        # note = "for browser, workorder photos will NOT be in map OR photos"
        # note = "for device, workorder photos will be in map unless deleted , but may NOT be in photos"

        # not found in map, but still check if photos, WORKORDER_SYNC may update Editor attrs
        # foundInPhotos = _.find self.photos, (o)->return o.UUID[0...36] == photo.UUID[0...36]
        foundInPhotos = _.find self.photos, {UUID: photo.UUID}


        if !foundInPhotos && foundInMap 
          photo = _.extend foundInMap, photo
          photo.from = 'CameraRoll<PARSE'

          # notFound because a) dataURL not yet retrieved, or b) not in map() (added above)
          self.patchPhoto photo
          console.log "\n**** NEW photo from WORKORDER added to photos, uuid=" + photo.UUID

        else 
          # merge values set by Editor
          _.extend foundInPhotos, _.pick photo, ['topPick', 'favorite', 'shotId', 'isBestshot']
          # console.log "\n**** MERGE photo from WORKORDER into cameraRoll for uuid=" + photo.UUID
        return



      isDataURL : (src)->
        throw "isDataURL() ERROR: expecting string" if typeof src != 'string'
        return /^data:image/.test( src )

      ## @param options = {UUID: data: or dataURL:}
      ## options.data, options.dataURL:
      ##    dataURL from cameraRoll.addDataURL(),
      ##    fileURL from imageCacheSvc.cordovaFile_USE_CACHED_P, or 
      ##    PARSE URL from workorders
      addDataURL: (size, options)->
        # console.log "\n\n adding for size=" + size
        if !/preview|thumbnail/.test( size )
          return console.log "ERROR: invalid dataURL size, size=" + size
        _logOnce "sdkhda", "WARNING: NOT truncating to UUID(36), UUID="+options.UUID if options.UUID.length > 36

        imgSrc = options.data || options.dataURL
        self.dataURLs[size][options.UUID] = imgSrc

        if self.isDataURL(imgSrc) # cacheDataURLs
          $timeout ()->
              promise = imageCacheSvc.cordovaFile_CACHE_P( options.UUID, size, imgSrc).then (fileURL)->
                console.log "\n\n imageCacheSvc has cached dataURL, path=" + fileURL
                self.dataURLs[size][options.UUID] = fileURL
            , 10 
        # console.log "\n\n added!! ************* " 
        return self

      addParseURL : (parsePhoto, size)->
        self.dataURLs[size][parsePhoto.UUID] = parsePhoto.src
        return parsePhoto.src


      # load moments, but not photos
      loadMomentsFromCameraRoll: (mapped)->
        ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
        mapped = self._mapAssetsLibrary if !mapped

        # cameraRoll._mapAssetsLibrary -> cameraRoll.moments
        photosByDate = otgData.mapDateTakenByDays(mapped, "like TEST_DATA")
        # replace cameraRoll.moments
        justUUIDsByDate = {} # JUST [{date:[UUID,]},{}]
        _.each _.keys( photosByDate) , (key)->
          justUUIDsByDate[key] = _.map photosByDate[key], (o)->
            return o.UUID  # o.UUID[0...36]
        # console.log justUUIDsByDate
        self.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( justUUIDsByDate ), 2

        return self.moments


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

      # promise version, used by lazySrc
      getDataURL_P :  (UUID, size='preview', noCache)->
        found = self.getDataURL(UUID, size) if !noCache
        return $q.when(found) if found
        # load from cameraRoll
        role = if deviceReady.isWebView() then 'owner' else 'editor'
        switch role
          when 'owner'
            return snappiMessengerPluginService.getDataURLForAssets_P( 
              [UUID], 
              size, 
              self.patchPhoto 
            ).then (photos)->
                return photos[0]   # resolve( photo )
          when 'editor'
            # using Parse URLs instead of cameraRoll dataURLs
            previewURL = self.getDataURL(UUID, 'preview')
            if previewURL && /^http/.test( previewURL )
              return self.resampleP(previewURL, 64, 64).then (dataURL)->
                  photo = {
                      UUID: UUID
                      data: dataURL
                    }
                  self.addDataURL('thumbnail', photo )
                  return photo
                , (error)->
                  # console.log error # $$$
                  _logOnce 'yj38d', "\n\n *** getDataURL_P: Resample.js error: just use previewURL URL for thumbnail UUID=" + UUID + "\n\n"
                  photo = {
                    UUID: UUID
                    data: previewURL
                  }
                  self.addDataURL('thumbnail', photo )
                  return photo
            else 
              $q.reject('photo not available')


      resampleP : (imgOrSrc, W=320, H=null)->
        return $q.reject('Missing Image') if !imgOrSrc
        console.log "*** resize & convert to base64 using Resample.js ******* imgOrSrc=" + imgOrSrc
        dfd = $q.defer()
        done = (dataURL)->
          console.log "resampled data=" + JSON.stringify {
            size: dataURL.length
            data: dataURL[0..60]
          }
          dfd.resolve(dataURL)
          return
        try 
          Resample.one()?.resample imgOrSrc
            ,   W
            ,   H    # targetHeight
            ,   dfd
            ,   "image/jpeg"
        catch ex  
          dfd.reject(imgOrSrc)
        return dfd.promise

      ## @return string
      ##    dataURL from cameraRoll.addDataURL(),
      ##    fileURL from imageCacheSvc.cordovaFile_USE_CACHED_P, or 
      ##    PARSE URL from workorders, photo.src
      getDataURL: (UUID, size='preview')->
        if !/preview|thumbnail/.test size
          throw "ERROR: invalid dataURL size, size=" + size
        # console.log "$$$ camera.dataURLs lookup for UUID="+UUID+', size='+size

       

        # ??? 2nd check cordovaFile cache, works if we save to localStorage
        # because workorder URLs take precedence over fileURLS ??? 
        
        found = imageCacheSvc.isStashed(UUID, size)
        # self.dataURLs[size][UUID] = found.fileURL  if found # for localStorage

        # console.log self.dataURLs[size][UUID]
        found = self.dataURLs[size][UUID] if !found
        if !found && UUID.length == 36
          found = _.find self.dataURLs[size], (o,key)->
              return o if key[0...36] == UUID

      
        if !found # still not found, add to queue for fetch
          console.log "STILL NOT FOUND queueDataURL(UUID)=" + UUID
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
        # # don't wait for promise
        self.debounced_fetchDataURLsFromQueue()
        # return

        # $rootScope.$broadcast 'cameraRoll.queuedDataURL'


      queue: (clear, PREVIEW_LIMIT = 50 )->
        self._queue = {} if clear=='clear'

        thumbnails = _.filter self._queue, {size: 'thumbnail'}
        previews = _.filter self._queue, {size: 'preview'}

        if previews.length > PREVIEW_LIMIT
          _logOnce 'iegd', "cameraRoll.queue() 'preview' PREVIEW_LIMIT="+PREVIEW_LIMIT
          remainder = previews[PREVIEW_LIMIT..]

        batch = thumbnails.concat previews.slice(0, PREVIEW_LIMIT)
        self._queue = if remainder?.length then _.indexBy( remainder, 'UUID') else {}

        # order by thumbnails then previews
        return batch

      fetchDataURLsFromQueue : ()->
        queuedAssets = self.queue()

        chunks = {}
        _.each ['preview', 'thumbnail'], (size)->
          assets = _.filter queuedAssets, (o)->return o?.size == size
          chunks[size] = assets if assets.length
        console.log chunks

        promises = []
        _.each chunks, (assets, size)->
          console.log "\n\n *** fetchDataURLsFromQueueP START! size=" + size + ", count=" + assets.length + "\n"
          promises.push snappiMessengerPluginService.getDataURLForAssetsByChunks_P(
              assets, 
              size,
              self.patchPhoto 
            ).then (photos)->
              return photos 

        return $q.all(promises).then (o)->
            console.log "*** fetchDataURLsFromQueueP $q All Done! \n" 

      debounced_fetchDataURLsFromQueue : ()->
        return console.log "\n\n\n ***** ERROR: add debounce on init *********"


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

    self.debounced_fetchDataURLsFromQueue = _.debounce self.fetchDataURLsFromQueue
        , 1000
        , {
          leading: false
          trailing: true
          }

    deviceReady.waitP().then ()->
      if deviceReady.isWebView()
        # do NOT load TEST_DATA, wait for otgParse call by:
        # workorder: otgParse.fetchWorkorderPhotosByWoIdP()
        # top-picks: otgParse.fetchPhotosByOwnerP
        return
      else if $rootScope.user?.isRegistered
        # skip
        return
      else  
        return

    return self
]
.factory 'snappiMessengerPluginService', [
  '$rootScope', '$q', '$timeout',
  'deviceReady', 'appConsole', 'otgData'
  ($rootScope, $q, $timeout, deviceReady, appConsole, otgData)->

    # wrap $ionicPlatform ready in a promise, borrowed from otgParse   
    _MessengerPLUGIN = {
      MAX_PHOTOS: 200
      CHUNK_SIZE : 30
      SERIES_DELAY_MS: 100

      _callP : (method, data, TIMEOUT=2000)->
        dfd = $q.defer()
        cancel = $timeout ()->
            return dfd.reject("TIMEOUT: snappiMessengerPluginService - " + method)
          , TIMEOUT
        window.Messenger[method](  data
          , (resp)->
            $timeout.cancel(cancel)
            return dfd.resolve(resp)
          , (err)->
            $timeout.cancel(cancel)
            return dfd.reject(err)
        )
        return dfd.promise 

      on : 
        photoStreamChange : (handler)-> 
          #  updated:{array of phasset ids}, removed:{array of phasset ids}, added:{array of phasset ids}
          return window.Messenger.on( 'photoStreamChange', handler )


        didBeginAssetUpload : (handler)-> 
          #  asset:{string phasset id}
          return window.Messenger.on( 'didBeginAssetUpload', handler )

        didUploadAssetProgress : (handler)-> 
          # asset:{string phasset id}
          # totalBytesSent:
          # totalByesExpectedToSend:
          return window.Messenger.on( 'didUploadAssetProgress', handler )

        didFinishAssetUpload : (handler)-> 
          # asset:{string phasset id}, 
          # name:{string (Parse name)}    # Parse URL
          # success: bool
          return window.Messenger.on( 'didFinishAssetUpload', handler )


        # currently UNUSED
        lastImageAssetID : (handler)-> 
          #  No data passed
          return window.Messenger.on( 'lastImageAssetID', handler )

        #
        #  native CameraRoll picker control
        #
        # scheduleAssetsForUpload : (handler)-> 
        #   #  assets:{array of phasset ids}
        #   return window.Messenger.on( 'scheduleAssetsForUpload', handler )

        unscheduleAssetsForUpload : (handler)-> 
          #   assets:{array of phasset ids}
          return window.Messenger.on( 'unscheduleAssetsForUpload', handler )

        #
        #  native Calendar control
        #
        scheduleDayRangeForUpload : (handler)-> 
          #  fromDate:{string}, toDate:{string}
          return window.Messenger.on( 'scheduleDayRangeForUpload', handler )

        unscheduleDayRangeForUpload : (handler)-> 
          #  fromDate:{string}, toDate:{string}
          return window.Messenger.on( 'unscheduleDayRangeForUpload', handler )


      # For communicating back with the native, we’ve defined two methods for you to call. The first is a response to the same command for returning whatever is your last phasset that the native has given you, the second is for passing array of phasset ids to be scheduled for background upload. I am not exactly sure how this happens on the Cordova side but I am guessing there should be a method in the messenger you can call an pass in the command string and a dictionary. I’ve listed the command names and data dictionary key:value pairs.
      # //Responds
      lastImageAssetIDP : (resp)-> 
        # o = {  
        #  asset:[UUID, UUID, UUID, ... ]
        # }
        return _MessengerPLUGIN._callP( 'lastImageAssetID' )

      scheduleAssetsForUploadP : (assetIds, options)-> 
        # o = {  
        # assets:[UUID, UUID, UUID, ... ]
        # options:
        #   targetWidth: 640
        #   targetHeight: 640
        #   resizeMode: 'aspectFit'
        #   autoRotate: true
        #     
        # }
        return $q.when({}) if _.isEmpty assetIds
        data = {
          assets: assetIds
          options: options
        }
        console.log "\n\n*** scheduleAssetsForUpload, data=" + JSON.stringify( data )
        return _MessengerPLUGIN._callP( 'scheduleAssetsForUpload', data )  

      getScheduleAssetsP : ()-> 
        console.log "\n\n*** calling getScheduleAssetsP"
        return _MessengerPLUGIN._callP( 'getScheduledAssets')        

      mapAssetsLibraryP: (options={})->
        console.log "mapAssetsLibrary() calling window.Messenger.mapAssetsLibrary(assets)"

        # defaults = {
        #   # pluck: ['DateTimeOriginal', 'PixelXDimension', 'PixelYDimension', 'Orientation']
        #   fromDate: '2014-09-01'
        #   toDate: null
        # }
        # options = _.defaults options, defaults
        # options.fromDate = cameraRoll.getDateFromLocalTime(options.fromDate) if _.isDate(options.fromDate)
        # options.toDate = cameraRoll.getDateFromLocalTime(options.toDate) if _.isDate(options.toDate)

        return deviceReady.waitP().then (retval)->
          dfd = $q.defer()
          return $q.reject "ERROR: window.Messenger Plugin not available" if !(window.Messenger?.mapAssetsLibrary)
          # console.log "about to call Messenger.mapAssetsLibrary(), Messenger.properties=" + JSON.stringify _.keys window.Messenger.prototype 
          window.Messenger.mapAssetsLibrary (mapped)->
              ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
              # attributes: UUID, dateTaken, mediaType, MediaSubTypes, hidden, favorite, originalWidth, originalHeight
              # console.log "\n *** mapAssetsLibrary Got it!!! length=" + mapped.length
              return dfd.resolve ( mapped )
            , (error)->
              return dfd.reject("ERROR: MessengermapAssetsLibrary(), msg=" + JSON.stringify error)
          # console.log "called Messenger.mapAssetsLibrary(), waiting for callbacks..."
          return dfd.promise

      ##
      ## @param assets array [UUID,] or [{UUID:},{}]
      ## @param eachPhoto is a callback, usually supplied by cameraRoll
      ##
      getDataURLForAssets_P: (assets, size , eachPhoto)->
        # call getPhotosByIdP() with array
        return _MessengerPLUGIN.getPhotosByIdP( assets , size).then (photos)->
            _.each photos, (photo)->

              eachPhoto(photo) if _.isFunction eachPhoto

              return 

              # # # merge into cameraRoll.dataUrls
              # # # keys:  UUID,data,elapsed, and more...
              # # # console.log "\n\n>>>>>>>  getPhotosByIdP(" + photo.UUID + "), DataURL[0..80]=" + photo.data[0..80]
              # # # cameraRoll.dataUrls[photo.format][ photo.UUID[0...36] ] = photo.data
              # cameraRoll._addOrUpdatePhoto_FromCameraRoll(photo)
              # cameraRoll.addDataURL(photo.format, photo)
              # console.log "\n*****************************\n"

            console.log "\n********** updated cameraRoll.dataURLs for this batch ***********\n"

            return photos
          , (errors)->
            console.log errors
            return $q.reject(errors)  # pass it on

      ##
      ## primary entrypoint for getting assets from an array of UUIDs
      ## @param assets array [UUID,] or [{UUID:},{}]
      ##
      getDataURLForAssetsByChunks_P : (tooManyAssets, size, eachPhoto, delayMS=0)->
        if tooManyAssets.length < _MessengerPLUGIN.CHUNK_SIZE
          return _MessengerPLUGIN.getDataURLForAssets_P(tooManyAssets, size, eachPhoto) 
        # load dataURLs for assets in chunks
        chunks = []
        chunkable = _.clone tooManyAssets
        chunks.push chunkable.splice(0, _MessengerPLUGIN.CHUNK_SIZE ) while chunkable.length
        # console.log "\n ********** chunk count=" + chunks.length

        
        ## in Parallel, overloads device
        if !delayMS
          promises = []
          _.each chunks, (assets, i, l)->
            # console.log "\n\n>>> chunk="+i+ " of length=" + assets.length
            promise = _MessengerPLUGIN.getDataURLForAssets_P( assets, size, eachPhoto )
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
          return _MessengerPLUGIN.getDataURLForAssets_P( assets, size, eachPhoto).then (chunkOfPhotos)->
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
              end = new Date().getTime()
              elapsed = (end-start)/1000
              console.log "\n>>>>>>>> window.Messenger.getPhotoById()  complete, count=" + retval.photos.length + " , elapsed=" + elapsed + "\n\n"
              return dfd.resolve ( retval.photos ) 
            else if retval.photos.length && retval.errors.length 
              console.log "WARNING: SOME errors occurred in Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
              # ???: how do we handle the errors? save them until last?
              return dfd.resolve ( retval.photos ) 
            else if retval.errors.length 
              console.error "ERROR: Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
              return dfd.reject retval.errors


          _patchOrientation = (photo)->
            # http://cloudintouch.it/2014/04/03/exif-pain-orientation-ios/
            lookup = [1,3,6,8,2,4,5,7]
            if photo.UIImageOrientation?
              photo.orientation == 'unknown' 
            else 
              photo.orientation = lookup[ photo.UIImageOrientation ] 
              delete photo.UIImageOrientation
            return 

          window.Messenger.getPhotoById assetIds, options, (photo)->
              # dupe = _.clone photo
              # dupe.data = dupe.data[0..40]
              # console.log dupe

              # one callback for each element in assetIds
              end = new Date().getTime()
              ## expecting photo keys: [data,UUID,dateTaken,originalWidth,originalHeight]
              ## NOTE: extended attrs from mapAssetsLibrary: UUID, dateTaken, mediaType, MediaSubTypes, hidden, favorite, originalWidth, originalHeight
              # photo.elapsed = (end-start)/1000
              photo.from = 'cameraRoll'
              photo.autoRotate = options.autoRotate
              photo.orientation = _patchOrientation( photo )  # should be EXIF orientation

              if (photo.autoRotate)
                # originalHeight/Width is not swapping
                _logOnce '4j9', "Messenger Plugin.getPhotosByIdP(): WARNING originalH/W not swapping on autoRotate" 

              # plugin method options              
              photo.format = options.type  # thumbnail, preview, previewHD
              photo.crop = options.resizeMode == 'aspectFill'
              photo.targetWidth = options.targetWidth
              photo.targetHeight = options.targetHeight

              _logOnce '4jsdf9',  "*** window.Messenger.getPhotoById success!! *** elapsed=" + (end-start)/1000

              retval.photos.push photo
              remaining--
              return _resolveIfDone(remaining, retval, dfd)
            , (error)->
              # example: {"message":"Base64 encoding failed","UUID":"05B86AB8-7C56-41DA-A6D8-E6D1F01B2620/L0/001"}
              # skip future uploads
              retval.errors.push error
              remaining--
              return _resolveIfDone(remaining, retval, dfd)

          return dfd.promise

    }
    return _MessengerPLUGIN
]

