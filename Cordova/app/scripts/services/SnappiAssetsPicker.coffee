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
  '$q', '$timeout',  '$ionicPlatform', '$cordovaNetwork', '$localStorage', 'otgLocalStorage'
  ($q, $timeout, $ionicPlatform, $cordovaNetwork, $localStorage, otgLocalStorage)->

    otgLocalStorage.loadDefaultsIfEmpty('device')

    _promise = null
    _timeout = 2000
    _contentWidth = null 
    _device = {}    # read only

    self = {

      deviceId: ()->  # DEPRECATE
        return $localStorage['device'].id

      isWebView: ()-> # DEPRECATE
        return $localStorage['device'].isDevice

      device: ()->
        return _device

      contentWidth: (force)->
        return _contentWidth if _contentWidth && !force
        return _contentWidth = document.getElementsByTagName('ion-side-menu-content')[0]?.clientWidth
          
      waitP: ()->
        return _promise if _promise
        deferred = $q.defer()
        _cancel = $timeout ()->
            console.warn "$ionicPlatform.ready TIMEOUT!!!"
            return deferred.reject("ERROR: ionicPlatform.ready does not respond")
          , _timeout
        $ionicPlatform.ready ()->
          $timeout.cancel _cancel
          platform = _.defaults ionic.Platform.device(), {
            available: false
            cordova: false
            platform: 'browser'
            uuid: 'browser'
          }
          $localStorage['device'] = {
            id: platform.uuid
            platform : platform
            isDevice: ionic.Platform.isWebView()
            isBrowser: ionic.Platform.isWebView() == false
           }
          _device = angular.copy $localStorage['device']
          console.log "$ionicPlatform reports deviceReady, device.id=" + $localStorage['device'].id
          return deferred.resolve( _device )
        return _promise = deferred.promise

      isOnline: ()->
        return true if $localStorage['device'].isBrowser
        return !$cordovaNetwork.isOffline()
    }
    return self
]
.factory 'cameraRoll', [
  '$q', '$timeout', '$rootScope', 'deviceReady', 'PLUGIN_CAMERA_CONSTANTS', 'snappiMessengerPluginService', 'imageCacheSvc'
  'TEST_DATA', 'otgData', 'appConsole'
  ($q, $timeout, $rootScope, deviceReady, CAMERA, snappiMessengerPluginService, imageCacheSvc, 
    TEST_DATA, otgData, appConsole)->
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
      # array of photos, use found = _.findWhere cameraRoll.map(), (UUID: uuid)
      # props: id->UUID, date, src, caption, rating, favorite, topPick, shared, exif
      #   plugin adds: dateTaken, origH, origW, height, width, crop, orientation,
      #   parse adds: assetId, from, createdAt, updatedAt
      dataURLs: {
        preview: {}     # indexBy UUID
        thumbnail: {}   # indexBy UUID
      }
      readyP: ()->
        return 

      map: (snapshot)->
        self._mapAssetsLibrary = angular.copy snapshot if `snapshot!=null`
        return self._mapAssetsLibrary

      mapP: (options, force=null)->
        if !force && self._mapAssetsLibrary?
          $rootScope.$broadcast('sync.cameraRollComplete', {changed:false})
          return $q.when self._mapAssetsLibrary 

        return snappiMessengerPluginService.mapAssetsLibraryP(options) 
        .then ( mapped )->
          if _.isEmpty self._mapAssetsLibrary
            self._mapAssetsLibrary = mapped 
            $rootScope.$broadcast('sync.cameraRollComplete', {changed:true})
          else if force
            # NOTE: this will reflect deletions if we don't merge
            self._mapAssetsLibrary = mapped 
            $rootScope.$broadcast('sync.cameraRollComplete', {changed:true})
          else
            'not updated'
          return mapped

      setFavoriteP: (photo)->
        return snappiMessengerPluginService.setFavoriteP(photo)


      loadCameraRollP: (options, force=true)->
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
        return self.mapP(options, force)
        .then (mapped)->
          promise = self.loadFavoritesP(5000)
          # don't wait for promise
          return mapped

        .then ( mapped )->

          end = new Date().getTime()
          console.log "\n*** mapAssetsLibraryP() complete, elapsed=" + (end-start)/1000

          # don't wait for promise
          moments = self.loadMomentsFromCameraRoll( mapped )
          promise = self.loadMomentThumbnailsP().then ()->
            console.log "\n @@@load cameraRoll thumbnails loaded from loadCameraRollP()"

          # cameraRoll ready
          return mapped

        .catch (error)->
          console.warn "ERROR: loadCameraRollP, error="+JSON.stringify( error )[0..100]
          # appConsole.show( error)
          return $q.reject(error)

        .finally ()->
          return

      loadFavoritesP: (delay=10)->
        # load 'preview' of favorites from cameraRoll, from mapAssetsLibrary()
        favorites = _.filter self.map(), {favorite: true}
        options = {size: 'preview'}
        # check against imageCacheSvc
        notCached = _.filter favorites, (photo)->
            return false if imageCacheSvc.isStashed( photo.UUID, options.size ) 
            return false if self.dataURLs[options.size][photo.UUID]?
            return true
        console.log "\n\n\n*** preloading favorite previews for UUIDs, count=" + notCached.length 
        # console.log notCached
        return self.loadPhotosP(notCached, options, delay)

      loadMomentThumbnailsP: (delay=10)->
        # preload thumbnail DataURLs for self moment previews
        momentPreviewAssets = self.getMomentPreviewAssets() 
        options = {
          size: 'thumbnail'
        }
        
        notCached = _.filter( 
          momentPreviewAssets
          , (photo)->
            return false if imageCacheSvc.isStashed( photo.UUID, options.size) 
            return false if self.dataURLs[options.size][photo.UUID]?
            return true
        )
        console.log "\n\n\n*** preloading moment thumbnails for UUIDs, count=" + notCached.length 
        # console.log notCached
        $rootScope.$broadcast 'cameraRoll.beforeLoadMomentThumbnails' # for cancel loading timer
        return self.loadPhotosP(notCached, options, delay)



      loadPhotosP: (photos, options, delay=10)->
        return $q.when('success') if _.isEmpty photos
        dfd = $q.defer()
        _fn = ()->
            start = new Date().getTime()
            return snappiMessengerPluginService.getDataURLForAssetsByChunks_P( 
              photos
              , options                         
              # , null  # onEach, called for cameraRoll thumbnails and favorites
              , (photo)->
                dataType = if photo.data[0...10]=='data:image' then 'DATA_URL' else 'FILE_URI'
                if dataType == 'FILE_URI'
                  imageCacheSvc.stashFile(photo.UUID, options.size, photo.data, photo.dataSize) # FILE_URI
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
                  photos: cameraRoll.map()[0..TEST_LIMIT]
                  dataURLs: {}
                }
                if deviceReady.device().isDevice
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

      addOrUpdatePhoto_FromWorkorder: (photo)->
        # photo could be in local cameraRoll, or if $rootScope.$state.includes('app.workorders') a workorder photo
        isLocal = (photo.deviceId == $rootScope.device.id)
        # console.log "%%% isLocal=" + (photo.deviceId == $rootScope.device.id) + ", values=" + JSON.stringify [photo.deviceId , $rootScope.device.id]

        foundInMap = _.find self.map(), {UUID: photo.UUID} # also putting workorder photos in map()

        if isLocal && !foundInMap
          console.warn "WARNING: this photo should be in the cameraRoll, UUID=" +photo.UUID
          throw "\n\n %%% WARNING: this photo should be in the cameraRoll, UUID=" +photo.UUID

        # typically called from Editor Workstation in Browser, in this case, there is no local CameraRoll
        # called from otgWorkorderSync._patchParsePhotos() with photo.date, photo.from set
        if !foundInMap # isWorkorder
          if photo.src[0...4] != 'http'
            # do not add inavlid photos
            photo.isInvalid = true  # deprecate
            return false 

          # only copy ready photos
          self._mapAssetsLibrary.push _.pick photo, [ 'objectId'
            'UUID', 'dateTaken', 'from', 'deviceId', 'caption', 'rating', 'favorite', 'topPick', 'shared', 'exif'
            'originalWidth', 'originalHeight'
            "hidden", "mediaType",  "mediaSubTypes", "burstIdentifier", "burstSelectionTypes", "representsBurst",
            'src'
          ]
          self.dataURLs['preview'][photo.UUID] = photo.src
          return false 
        else if isLocal # update in map()
          _.extend foundInMap, _.pick photo, ['from', 'caption', 'rating', 'favorite', 'topPick', 'shared', 'shotId', 'isBestshot', 'objectId'] # copy Edit fields
          foundInMap.from = 'CameraRoll<PARSE' 
          # cameraRoll photo.favorite has priority
          # BUT, we need to listen for onChange favorite OUTSIDE app and post(?)
          console.log "%%% isLocal, photo=" + JSON.stringify _.pick  foundInMap, ['from', 'caption', 'rating', 'xxxfavorite', 'topPick', 'shared', 'shotId', 'isBestshot', 'objectId']
          return true # triggers $broadcast cameraRoll.updated for topPicks refresh
        else if !isLocal && foundInMap # update Workorder Photo from Parse
          _.extend foundInMap, _.pick photo, ['from', 'caption', 'rating', 'favorite', 'topPick', 'shared', 'shotId', 'isBestshot'] # copy Edit fields
          # self.dataURLs['preview'][photo.UUID] = photo.src
          if $state.includes('app.workorders') == false
            console.log "%%% NOT isLocal, photo=" + JSON.stringify _.pick foundInMap, ['from', 'caption', 'rating', 'favorite', 'topPick', 'shared', 'shotId', 'isBestshot']
          return false


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
                # console.log "\n\n imageCacheSvc has cached dataURL, path=" + fileURL
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
          justUUIDsByDate[key] = _.pluck photosByDate[key], 'UUID'
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

      ### called by: 
          directive:lazySrc AFTER imgCacheSvc.isStashed_P().catch
          otgParse.uploadPhotoFileP
          otgUploader.uploader.type = 'parse'
      ###
      ###
      TODO: refactor, now using by default
      options.DestinationType = CAMERA.DestinationType.FILE_URI 
      ###
      getDataURL_P :  (UUID, options)->
        options = _.defaults options, {
          size: 'preview'
          noCache : false
          DestinationType : CAMERA.DestinationType.FILE_URI 
        }

        found = self.getDataURL(UUID, options.size) if !options.noCache
        return $q.when(found) if found
        # load from cameraRoll
        role = if deviceReady.device().isDevice then 'owner' else 'editor'
        switch role
          when 'owner'   # !! DEVICE, check deviceId as well
            return snappiMessengerPluginService.getDataURLForAssets_P( 
              [UUID], 
              options, 
              null  # onEach # ???: this is null
            ).then (photos)->
                return photos[0]   # resolve( photo )
          when 'editor' # browser
            # using Parse URLs instead of cameraRoll dataURLs
            previewURL = self.getDataURL(UUID, 'preview')
            if previewURL && /^http/.test( previewURL )
              # should be FileURL from parse
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

      ### queue photo for retrieval, put into imgCacheSvc for later access
        called by: 
          directive:lazySrc
          otgUploader.uploader.type = 'parse'
          cameraRoll.getPhoto()  ?? DEPRECATE?
      ###
      ## @return string
      ##    dataURL from cameraRoll.addDataURL(),
      ##    fileURL from imageCacheSvc.cordovaFile_USE_CACHED_P, or 
      ##      snappiMessengerPluginService.getDataURLForAssets_P([UUID], options.DestinationType=1)
      ##    PARSE URL from workorders, photo.src
      ##
      getDataURL: (UUID, size='preview')->
        if !/preview|thumbnail/.test size
          throw "ERROR: invalid dataURL size, size=" + size
        # console.log "$$$ camera.dataURLs lookup for UUID="+UUID+', size='+size

       

        # ??? 2nd check cordovaFile cache, works if we save to localStorage
        # because workorder URLs take precedence over fileURLS ??? 
        
        found = imageCacheSvc.isStashed(UUID, size)
        # self.dataURLs[size][UUID] = found.fileURL  if found # for localStorage

        # console.log self.dataURLs[size][UUID]
        # DEPRECATE if we are using DestinationType = FILE_URI
        found = self.dataURLs[size][UUID] if !found
        if !found && UUID.length == 36
          found = _.find self.dataURLs[size], (o,key)->
              return o if key[0...36] == UUID

      
        if !found # still not found, add to queue for fetch
          console.log "STILL NOT FOUND queueDataURL(UUID)=" + UUID
          self.queueDataURL(UUID, size)
          # calls:
           # > debounced_fetchDataURLsFromQueue 
           #   > fetchDataURLsFromQueue 
           #     > queue()
           #     > getDataURLForAssetsByChunks_P()
        return found


      # IMAGE_WIDTH should be computedWidth - 2 for borders
      getCollectionRepeatHeight : (photo, IMAGE_WIDTH)->
        if !IMAGE_WIDTH
          MAX_WIDTH = if deviceReady.device().isDevice then 320 else 640
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
        else 
          h = photo.scaledH
        return h

      # called by getDataURL, but NOT getDataURL_P
      queueDataURL : (UUID, size='preview')->
        console.warn "@@@@@@  DEPRECATE??? cameraRoll.queueDataURL"
        return if deviceReady.device().isBrowser
        self._queue[UUID] = { 
          UUID: UUID
          size: size, 
        }
        # # don't wait for promise
        self.debounced_fetchDataURLsFromQueue()
        # return

        # $rootScope.$broadcast 'cameraRoll.queuedDataURL'

      # getter, or reset queue
      queue: (clear, PREVIEW_LIMIT = 50 )->
        console.warn "@@@@@@  DEPRECATE??? cameraRoll.queue"
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

      # called by cameraRoll.queueDataURL()
      fetchDataURLsFromQueue : ()->
        console.warn "@@@@@@  cameraRoll.fetchDataURLsFromQueue"
        queuedAssets = self.queue()

        chunks = {}
        _.each ['preview', 'thumbnail'], (size)->
          assets = _.filter queuedAssets, (o)->return o?.size == size
          chunks[size] = assets if assets.length
        # console.log chunks


        promises = []
        _.each chunks, (assets, size)->
          console.log "\n\n *** fetchDataURLsFromQueueP START! size=" + size + ", count=" + assets.length + "\n"
          promises.push snappiMessengerPluginService.getDataURLForAssetsByChunks_P(
              assets, 
              {size: size},
              (photo)->
                dataType = if photo.data[0...10]=='data:image' then 'DATA_URL' else 'FILE_URI'
                if dataType == 'FILE_URI'
                  imageCacheSvc.stashFile(photo.UUID, size, photo.data, photo.dataSize) # FILE_URI
            ).then (photos)->
              return photos 

        return $q.all(promises).then (o)->
            console.log "*** fetchDataURLsFromQueueP $q All Done! \n" 

      debounced_fetchDataURLsFromQueue : ()->
        return console.log "\n\n\n ***** Placeholder: add debounce on init *********"


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
      if deviceReady.device().isDevice
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
  'deviceReady', 'PLUGIN_CAMERA_CONSTANTS', 'appConsole', 'otgData'
  ($rootScope, $q, $timeout, deviceReady, CAMERA, appConsole, otgData)->

    # wrap $ionicPlatform ready in a promise, borrowed from otgParse   
    _MessengerPLUGIN = {
      MAX_PHOTOS: 200
      CHUNK_SIZE : 30
      SERIES_DELAY_MS: 100

      on : 
        XXXphotoStreamChange : (handler)-> 
          #  updated:{array of phasset ids}, removed:{array of phasset ids}, added:{array of phasset ids}
          return window.Messenger.on( 'photoStreamChange', handler )


        didBeginAssetUpload : (handler)-> 
          # called AFTER background task is scheduled, see also: didFailToScheduleAsset()
          #  asset:{string phasset id}
          return window.Messenger.on( 'didBeginAssetUpload', handler )

        didUploadAssetProgress : (handler)-> 
          # asset:{string phasset id}
          # totalBytesSent:
          # totalByesExpectedToSend:
          return window.Messenger.on( 'didUploadAssetProgress', handler )

        didFinishAssetUpload : (handler)-> 
          # asset:{string phasset id}, 
          # call sessionTaskInfoForIdentifier(resp.asset) to get status
          return window.Messenger.on( 'didFinishAssetUpload', handler )


        # currently UNUSED
        lastImageAssetID : (handler)-> 
          #  No data passed
          return window.Messenger.on( 'lastImageAssetID', handler )

        #
        #  native CameraRoll picker control
        #

        didFailToScheduleAsset : (handler)-> 
          # resp = { asset, errorCode, isMissing }
          # resp.isMissing==true if UUID does not exist, fail BEFORE task scheduling
          # otherwise, check resp.errorCode
          return window.Messenger.on( 'didFailToScheduleAsset', handler )

        XXXunscheduleAssetsForUpload : (handler)-> 
          #   assets:{array of phasset ids}
          return window.Messenger.on( 'unscheduleAssetsForUpload', handler )

        #
        #  native Calendar control
        #
        XXXscheduleDayRangeForUpload : (handler)-> 
          #  fromDate:{string}, toDate:{string}
          return window.Messenger.on( 'scheduleDayRangeForUpload', handler )

        XXXunscheduleDayRangeForUpload : (handler)-> 
          #  fromDate:{string}, toDate:{string}
          return window.Messenger.on( 'unscheduleDayRangeForUpload', handler )



      _callP : (method, data, TIMEOUT=10000)->
        return $q.when "Messenger Plugin not available" if !window.Messenger?
        dfd = $q.defer()
        cancel = $timeout ()->
            return dfd.reject("TIMEOUT: snappiMessengerPluginService - " + method)
          , TIMEOUT
        onSuccess = (resp)->
            console.log ">>> callP returned for method=" + method + ", resp=" + JSON.stringify(resp)[0..100]
            $timeout.cancel(cancel)
            return dfd.resolve(resp)
        onError = (err)->
            $timeout.cancel(cancel)
            return dfd.reject(err)
        switch method
          when 'getScheduledAssets', 'unscheduleAllAssets'
          ,'suspendAllAssetUploads', 'resumeAllAssetUploads'
          ,'allSessionTaskInfos'
            args = [onSuccess]
          when 'scheduleAssetsForUpload', 'unscheduleAssetsForUpload'
          ,'sessionTaskInfoForIdentifier', 'removeSessionTaskInfoWithIdentifier'
          , 'setAllowsCellularAccess'
            args = [data, onSuccess, onError]
          when 'setFavorite'
            args = [data.UUID, data.favorite, onSuccess, onError]
          else
            throw "ERROR: invalid method. name=" + method
        # console.log ">>> callP calling method=" + method + ", args.length=" + args.length     
        window.Messenger[method].apply( this, args )
        return dfd.promise 

      setAllowsCellularAccessP : (value)->
        return _MessengerPLUGIN._callP( 'setAllowsCellularAccess', value ) 

      setFavoriteP : (photo)->
        data = _.pick photo, ['UUID', 'favorite']
        return _MessengerPLUGIN._callP( 'setFavorite', data ) 

      scheduleAssetsForUploadP : (assetIds, options)-> 
        # o = {  
        # assets:[UUID, UUID, UUID, ... ]
        # options:
        #   autoRotate: true
        #   maxWidth: 0
        # }
        return $q.when({}) if _.isEmpty assetIds
        data = {
          assets: assetIds
          options: options
        }
        console.log "\n\n*** scheduleAssetsForUpload, data=\n" + JSON.stringify( data )
        return _MessengerPLUGIN._callP( 'scheduleAssetsForUpload', data )  

      getScheduledAssetsP : ()-> 
        # console.log "\n\n*** calling getScheduledAssetsP"
        return _MessengerPLUGIN._callP( 'getScheduledAssets')  

      unscheduleAllAssetsP : ()-> 
        # console.log "\n\n*** calling unscheduleAllAssets"
        return _MessengerPLUGIN._callP( 'unscheduleAllAssets')  

      suspendAllAssetUploadsP : ()->
        return _MessengerPLUGIN._callP( 'suspendAllAssetUploads') 

      resumeAllAssetUploadsP : ()->
        # WARNING: plugin method is misspelled
        return _MessengerPLUGIN._callP( 'resumeAllAssetUploads') 

      allSessionTaskInfosP : ()->
        # resp = [{ asset, progress, hasFinished, success, errorCode, name }]
        return _MessengerPLUGIN._callP( 'allSessionTaskInfos') 

      sessionTaskInfoForIdentifierP : (UUID)->
        # resp = { asset, progress, hasFinished, success, errorCode, url, name }
          # asset: "AC072879-DA36-4A56-8A04-4D467C878877/L0/001"
          # errorCode: 0, ERROR_CANCELLED = -999
          # hasFinished: true
          # name: "tfss....jpg"
          # progress: 1
          # success: 1
          # url: "http://files.parsetfss.com/tfss....jpg"
        
        # onError: no info for UUID
        return _MessengerPLUGIN._callP( 'sessionTaskInfoForIdentifier', UUID) 

      removeSessionTaskInfoWithIdentifierP : (UUID )->
        # onError: UUID not found
        return _MessengerPLUGIN._callP( 'removeSessionTaskInfoWithIdentifier', UUID) 


      mapAssetsLibraryP: (options={})->
        # console.log "mapAssetsLibrary() calling window.Messenger.mapAssetsLibrary(assets)"

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
      ## @param options = { DestinationType:, size: }
      ## @param eachPhoto is a callback, usually supplied by cameraRoll
      ##
      getDataURLForAssets_P: (assets, options, eachPhoto)->
        # call getPhotosByIdP() with array
        options = _.defaults options, {
          size: 'preview'
          DestinationType : CAMERA.DestinationType.FILE_URI 
        }
        return _MessengerPLUGIN.getPhotosByIdP( assets , options).then (photos)->
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
      getDataURLForAssetsByChunks_P : (tooManyAssets, options, eachPhoto, delayMS=0)->
        if tooManyAssets.length < _MessengerPLUGIN.CHUNK_SIZE
          return _MessengerPLUGIN.getDataURLForAssets_P(tooManyAssets, options, eachPhoto) 
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
            promise = _MessengerPLUGIN.getDataURLForAssets_P( assets, options, eachPhoto )
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
          return _MessengerPLUGIN.getDataURLForAssets_P( assets, options, eachPhoto)
          .then (chunkOfPhotos)->
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
      getPhotosByIdP: (assets, options={} )->
        return $q.when([]) if _.isEmpty assets
        # takes asset OR array of assets
        options.size = options.size || 'thumbnail'

        defaults = {
          preview: 
            targetWidth: 720
            targetHeight: 720
            resizeMode: 'aspectFit'
            autoRotate: true
            DestinationType: CAMERA.DestinationType.FILE_URI  # 1
          previewHD: 
            targetWidth: 1080
            targetHeight: 1080
            resizeMode: 'aspectFit'
            autoRotate: true
            DestinationType: CAMERA.DestinationType.FILE_URI  # 1
          thumbnail:
            targetWidth: 64
            targetHeight: 64
            resizeMode: 'aspectFill'
            autoRotate: true
            DestinationType: CAMERA.DestinationType.FILE_URI  # 1
        }
        options = _.extend options, defaults.preview if options.size=="preview"
        options = _.extend options, defaults.thumbnail if options.size=="thumbnail"
        options = _.extend options, defaults.previewHD if options.size=="previewHD"

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

