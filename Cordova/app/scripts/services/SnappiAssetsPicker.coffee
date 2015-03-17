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

.factory 'cameraRoll', [
  '$q', '$timeout', '$rootScope', 'deviceReady', 'PLUGIN_CAMERA_CONSTANTS', 'snappiMessengerPluginService', 'imageCacheSvc'
   'otgData', 'appConsole'
  ($q, $timeout, $rootScope, deviceReady, CAMERA, snappiMessengerPluginService, imageCacheSvc, otgData, appConsole)->
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

      'iOSCollections': {
        ## methods specific to iOS photos framework collections for GPS labels
        _raw: []
        # {'2015-02-22':[ count, label, location, location, ... ] }
        _parsed: {}


        getLabelForDates: (dates, sort='weight')->
          byDate = self.iOSCollections.getByDate()
          byDate['2014-09-08'] = byDate['2015-02-17'] 
          byDate['2014-09-07'] = byDate['2015-02-19'] 
          byDate['2014-09-06'] = byDate['2015-02-18'] 


          switch sort
            when 'weight'
              dates.sort().reverse()
              byWeight = _.reduce dates, (result, date)->
                  return result if !byDate[date]
                  [count, label, locations...] = byDate[date]
                  result.push {date: date, count: byDate[date][0] }
                  return result
                , []
              byWeight = _.sortBy byWeight, 'count'
              byWeight.reverse()              

              # dates = dates.sort()
              dates = _.pluck byWeight, 'date'
            when 'date'
              dates.sort()

          label = _.reduce dates, (result, date)->

              return result if !byDate[date]
              [count, label, locations...] = byDate[date]

              result.labels.push label
              result.locations = result.locations.concat locations
              return result;
            , {
              labels: []
              locations: []
            }

          _.each _.keys( label), (key)-> label[key] = _.unique label[key]
          return label

        getByDate: ()-> 
          return self.iOSCollections._parsed

        mapP: (force=null)->
          if !_.isEmpty(self.iOSCollections._parsed) && !force 
            return $q.when(self.iOSCollections._parsed) 
          

          start = new Date().getTime()
          if deviceReady.device().isBrowser
            return _.isEmpty window.TEST_DATA # load in _LOAD_BROWSER_TOOLS()
            promise = $q.when(TEST_DATA.iosCollections)
          else
            promise = snappiMessengerPluginService.mapCollectionsP()

          return promise.then (collections)->
            self.iOSCollections._raw = collections
            self.iOSCollections._parsed = otgData.parseIOSCollections( self.iOSCollections._raw )
            console.log "\nCameraRoll.iOSCollections.mapP() elapsed=", (new Date().getTime() - start)
            return self.iOSCollections._parsed   
      }
      mapP: (options, force=null)->
        if !force && self._mapAssetsLibrary?
          $rootScope.$broadcast('sync.cameraRollComplete', {changed:false})
          return $q.when self._mapAssetsLibrary 

        return snappiMessengerPluginService.mapAssetsLibraryP(options) 
        .then ( mapped )->
          _.each mapped, (o)->
            o.from = 'CameraRoll'
            o.deviceId = $rootScope.device.id
            return
          if _.isEmpty self._mapAssetsLibrary
            self._mapAssetsLibrary = mapped 
            $rootScope.$broadcast('sync.cameraRollComplete', {changed:true})
          else if force == 'merge'
            # refresh cameraRoll should not reset PARSE photos. only do so on clearPhotos_PARSE
            # MERGE into existing map() to avoid topPicks flash
            added = _.difference _.pluck(mapped, 'UUID'), _.pluck(self._mapAssetsLibrary, 'UUID')
            removed = _.difference _.pluck(self.filterDeviceOnly(), 'UUID'), _.pluck(mapped, 'UUID') 
            changed = false
            if removed.length
              self._mapAssetsLibrary = _.filter self._mapAssetsLibrary, (o)->
                return removed.indexOf(o.UUID) == -1
            if added.length
              addedObjs = _.filter mapped, (o)->
                return added.indexOf(o.UUID) > -1
              self._mapAssetsLibrary = self._mapAssetsLibrary.concat addedObjs

            # reset favorites
            favorites = {}
            _.each mapped, (o)->
              favorites[o.UUID] = !!o.favorites
              return
            _.each self._mapAssetsLibrary, (o)->
              return if o.favorites == favorites[o.UUID]
              o.favorites = favorites[o.UUID]
              changed = true
              return

            changed = changed || removed.length || added.length
            $rootScope.$broadcast('sync.cameraRollComplete', {changed:true}) if changed
          else if force=='replace'
            # mapped = mapped.concat( self.filterParseOnly() )
            self._mapAssetsLibrary = mapped 
            $rootScope.$broadcast('sync.cameraRollComplete', {changed:true})
          else
            'not updated'
          return self._mapAssetsLibrary

      filterDeviceOnly: (photos)->
        photos = photos || self.map()
        return _( photos ).filter( (o)->return !o.from || o.from.slice(0,5)!='PARSE' ).value()


      filterParseOnly: (photos)->
        photos = photos || self.map()
        return _( photos ).filter( (o)->return o.from =='PARSE' ).value()

      setFavoriteP: (photo)->
        return snappiMessengerPluginService.setFavoriteP(photo)


      loadCameraRollP: (options, force='merge')->
        defaults = {
          size: 'thumbnail'
          type: 'favorites,moments' # defaults
          # pluck: ['favorite','mediaType', 'mediaSubTypes', 'hidden']  
          # fromDate: null
          # toDate: null
        }
        options = _.defaults options || {}, defaults
        # options.fromDate = self.getDateFromLocalTime(options.fromDate) if _.isDate(options.fromDate)
        # options.toDate = self.getDateFromLocalTime(options.toDate) if _.isDate(options.toDate)

        start = new Date().getTime()
        return self.mapP(options, force)
        .then (mapped)->
          forceCollection = $rootScope.$state.includes('app.choose.camera-roll') && force
          promise = self.iOSCollections.mapP(forceCollection)
          return mapped
        .then (mapped)->
          promise = self.loadFavoritesP(5000) if options.type.indexOf('favorites') > -1
          # don't wait for promise
          return mapped

        .then ( mapped )->

          # end = new Date().getTime()
          # console.log "\n*** mapAssetsLibraryP() complete, elapsed=" + (end-start)/1000
          return mapped if deviceReady.device().isBrowser

          # don't wait for promise
          if options.type.indexOf('moments') > -1
            moments = self.loadMomentsFromCameraRoll( mapped )
            promise = self.loadMomentThumbnailsP().then ()->
              # console.log "\n @@@load cameraRoll thumbnails loaded from loadCameraRollP()"
              return

          # cameraRoll ready
          return mapped

        .catch (error)->
          console.warn "ERROR: loadCameraRollP, error="+JSON.stringify( error )[0..100]
          # appConsole.show( error)
          if error == "ERROR: window.Messenger Plugin not available" && deviceReady.device().isBrowser
            self._mapAssetsLibrary = [] if force=='replace' && !window.TEST_DATA
            $rootScope.$broadcast 'cameraRoll.loadPhotosComplete', {type:'moments'}
            $rootScope.$broadcast 'cameraRoll.loadPhotosComplete', {type:'favorites'}
            return true
          return $q.reject(error)
        .finally ()->
          return

      loadFavoritesP: (delay=10)->
        # load 'preview' of favorites from cameraRoll, from mapAssetsLibrary()
        favorites = _.filter self.map(), {favorite: true}
        options = {
          size: 'preview'
          type: 'favorites'
        }
        # check against imageCacheSvc
        notCached = _.filter favorites, (photo)->
            return false if imageCacheSvc.isStashed( photo.UUID, options.size ) 
            return false if self.dataURLs[options.size][photo.UUID]?
            return true
        # console.log "\n\n\n*** preloading favorite previews for UUIDs, count=" + notCached.length 
        # console.log notCached
        return self.loadPhotosP(notCached, options, delay)

      # load moments, but not photos
      loadMomentsFromCameraRoll: (mapped)->
        ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
        # filter: remove  photos.from=='PARSE'
        deviceOnly = self.filterDeviceOnly mapped

        # cameraRoll._mapAssetsLibrary -> cameraRoll.moments
        photosByDate = otgData.mapDateTakenByDays(deviceOnly, "like TEST_DATA")
        # replace cameraRoll.moments
        justUUIDsByDate = {} # JUST [{date:[UUID,]},{}]
        _.each _.keys( photosByDate) , (key)->
          justUUIDsByDate[key] = _.pluck photosByDate[key], 'UUID'
        # console.log justUUIDsByDate
        self.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( justUUIDsByDate ), 2
        # done on 'cameraRoll.loadPhotosComplete', type=thumbnail
        return self.moments
        
      loadMomentThumbnailsP: (delay=10)->
        # preload thumbnail DataURLs for self moment previews
        momentPreviewAssets = self.getMomentPreviewAssets() 
        options = {
          size: 'thumbnail'
          type: 'moments'
        }
        
        notCached = _.filter( 
          momentPreviewAssets
          , (photo)->
            return false if imageCacheSvc.isStashed( photo.UUID, options.size) 
            return false if self.dataURLs[options.size][photo.UUID]?
            return true
        )
        # console.log "\n\n\n*** preloading moment thumbnails for UUIDs, count=" + notCached.length 
        # console.log notCached
        $rootScope.$broadcast 'cameraRoll.beforeLoadMomentThumbnails' # for cancel loading timer
        # done on 'cameraRoll.loadPhotosComplete', type=thumbnail
        if _.isEmpty notCached
          $rootScope.$broadcast 'cameraRoll.loadPhotosComplete', options # for cancel loading timer
          return $q.when 'success'
        return self.loadPhotosP(notCached, options, delay)

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

      loadPhotosP: (photos, options, delay=10)->
        options = _.defaults options || {} , {
          DestinationType: CAMERA.DestinationType.FILE_URI
        }
        return $q.when('success') if _.isEmpty photos
        dfd = $q.defer()
        _fn = ()->
            start = new Date().getTime()
            return snappiMessengerPluginService.getDataURLForAssetsByChunks_P( 
              photos
              , options                         
              # , null  # onEach, called for cameraRoll thumbnails and favorites
              , (photo)->
                if options.DestinationType == CAMERA.DestinationType.FILE_URI 
                  imageCacheSvc.stashFile(photo.UUID, options.size, photo.data, photo.dataSize) # FILE_URI
              , snappiMessengerPluginService.SERIES_DELAY_MS 
            )
            .then ()->
              end = new Date().getTime()
              # console.log "\n*** thumbnail preload complete, elapsed=" + (end-start)/1000
              $rootScope.$broadcast 'cameraRoll.loadPhotosComplete', options # for cancel loading timer
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



      addOrUpdatePhoto_FromWorkorder: (photo)->
        # photo could be in local cameraRoll, or if $rootScope.isStateWorkorder() a workorder photo
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
          foundInMap.woSrc = photo.src
          # cameraRoll photo.favorite has priority
          # BUT, we need to listen for onChange favorite OUTSIDE app and post(?)
          # console.log "%%% isLocal, photo=" + JSON.stringify _.pick  foundInMap, ['from', 'caption', 'rating', 'xxxfavorite', 'topPick', 'shared', 'shotId', 'isBestshot', 'objectId']
          return true # triggers $broadcast cameraRoll.updated for topPicks refresh
        else if !isLocal && foundInMap # update Workorder Photo from Parse
          _.extend foundInMap, _.pick photo, ['from', 'caption', 'rating', 'favorite', 'topPick', 'shared', 'shotId', 'isBestshot'] # copy Edit fields
          self.dataURLs['preview'][photo.UUID] = photo.src if !photo.src
          if deviceReady.device().isDevice && $rootScope.isStateWorkorder() == false
            console.log "%%% NOT isLocal, photo=" + JSON.stringify _.pick foundInMap, ['from', 'caption', 'rating', 'favorite', 'topPick', 'shared', 'shotId', 'isBestshot']
          return false

      clearPhotos_PARSE : ()->
        # on logout
        self._mapAssetsLibrary = self.filterDeviceOnly()

      clearPhotos_CameraRoll : ()->
        # on logout
        self._mapAssetsLibrary = self.filterParseOnly()      

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
          return console.warn "ERROR: invalid dataURL size, size=" + size
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








      ### #########################################################################
      # methods for getting photos from cameraRoll, isDevice==true
      ### #########################################################################  

      ### called by: 
          directive:lazySrc AFTER imgCacheSvc.isStashed_P().catch
          otgParse.uploadPhotoFileP
          otgUploader.uploader.type = 'parse'
          NOTE: use getPhoto_P() for noCache = true, i.e. fetch but do NOT cache
      ###
      ###
      # @params UUID, string, iOS example: '1E7C61AB-466A-468A-A7D5-E4A526CCC012/L0/001'
      # @params options object
      #   size: ['thumbnail', 'preview', 'previewHD']
      #   DestinationType : [0,1],  default CAMERA.DestinationType.FILE_URI 
      #   noCache: boolean, default false, i.e. cache the photo using imageCacheSvc.stashFile
      # @return photo object, {UUID: data: dataSize:, ...}
      # @throw error if photo.dataSize == 0
      ###
      getPhoto_P :  (UUID, options)->
        options = _.defaults options || {}, {
          size: 'preview'
          noCache : false
          DestinationType : CAMERA.DestinationType.FILE_URI 
        }

        if getFromCache = options.noCache == false # check imageCacheSvc
          found = self.getPhoto(UUID, options) 
        if isBrowser = deviceReady.device().isBrowser 
          found = self.getPhoto(UUID, options) 
        if isWorkorder = $rootScope.isStateWorkorder() 
          # HACK: for now, force workorders to get parse URLS, skip cameraRoll
          # TODO: check cameraRoll if owner is DIY workorder
          # i.e. workorderObj.get('devices').indexOf($rootScope.device.id) > -1
          found = self.getPhoto(UUID, options) 
        if found  
          photo = {
            UUID: UUID
            data: found
          }
          return $q.when(found) 
          

        # load from cameraRoll if workorderObj.get('devices').indexOf($rootScope.device.id) > -1
        if isDevice = !isBrowser 
          return snappiMessengerPluginService.getDataURLForAssets_P( 
            [UUID], 
            options, 
            null  # TODO: how should we merge for owner TopPicks?
          ).then (photos)->
              photo = photos[0]   # resolve( photo )
              if photo.dataSize == 0
                return $q.reject {
                  message: "error: dataSize==0"
                  UUID: UUID
                  size: options.size
                }
              return photo
        else 
          return $q.reject {
            message: 'ERROR: getPhoto_P()'
          }



      ### getPhoto if cached, otherwise queue for retrieval, 
          SAVE TO CACHE with imgCacheSvc or cameraRoll.dataURL
        called by: 
          directive:lazySrc
          otgUploader.uploader.type = 'parse'
      ###
      ###
      # @params UUID, string, iOS example: '1E7C61AB-466A-468A-A7D5-E4A526CCC012/L0/001'
      # @params options object
      #   size: ['thumbnail', 'preview', 'previewHD', 'orig'], default options.size=='preview'
      #   DestinationType : [0,1],  default CAMERA.DestinationType.FILE_URI       
      # @return found object { UUID: data: dataSize: }
      #    dataURL from cameraRoll.dataURls,
      #    fileURL from imageCacheSvc.cordovaFile_USE_CACHED_P, or 
      #      snappiMessengerPluginService.getPhotoForAssets_P([UUID], options.DestinationType=1)
      #    NOTE: PARSE FILE_URI from workorders, photo.src is set directly by directive:lazySrc
      ###
      getPhoto: (UUID, options)->
        options = _.defaults options || {}, {
          size: 'preview'
          DestinationType : CAMERA.DestinationType.FILE_URI 
          # noCache : false     # FORCE cache via queue
        }
        size = options.size
        if !/preview|thumbnail/.test size
          throw "ERROR: invalid dataURL size, size=" + size
        
        if options.DestinationType == CAMERA.DestinationType.FILE_URI
          stashed = imageCacheSvc.isStashed(UUID, size)
          if stashed
            found = {
              data: stashed.fileURL
              dataSize: stashed.fileSize
            }
        else 
          dataURL = self.dataURLs[size][UUID]
          if !dataURL && UUID.length == 36
            dataURL = _.find self.dataURLs[size], (o,key)->
                return o if key[0...36] == UUID
          if dataURL
            found = {
              data: dataURL
              dataSize: dataURL.length
            }
        if found # add extended attributes
          _.defaults found, options
          found['UUID'] = UUID
          return found

        # still not found, add to queue for fetch
          # console.log "image not cached, queuePhoto(UUID)=" + UUID
        self.queuePhoto(UUID, options)
        return null

      # fetch a photo by UUID, AND save to cache
      # called by getPhoto(), but NOT getPhoto_P()
      # self._queue is fetched by:
      # > debounced_fetchPhotosFromQueue 
      #   > fetchPhotosFromQueue 
      #     > getPhotoForAssetsByChunks_P()      
      queuePhoto : (UUID, options)->
        return if deviceReady.device().isBrowser
        item = _.defaults {UUID: UUID}, _.pick options, ['size', 'DestinationType']
        self._queue[UUID] = item
        # # don't wait for promise
        self.debounced_fetchPhotosFromQueue()
        # $rootScope.$broadcast 'cameraRoll.queuedPhoto'
        return


      # called by cameraRoll.queuePhoto()
      fetchPhotosFromQueue : ()->
        queuedAssets = self.queue()

        chunks = _.reduce queuedAssets, (result, o)->
            type = o.size + ':' + o.DestinationType
            result[type].push o.UUID
            return result
          , {
            'thumbnail:1': [] # Camera.DestinationType.FILE_URI ==1
            'preview:1': []
            'previewHD:1': []
            'thumbnail:0': [] # DATA_URL == 0
            'preview:0': []
            'previewHD:0': []            
          }

        promises = []
        _.each chunks, (assets, type)->
          # console.log "\n\n *** fetchPhotosFromQueueP START! size=" + size + ", count=" + assets.length + "\n"
          return if assets.length == 0
          [size, DestinationType] = type.split(':')
          options = {
            size: size
            DestinationType: DestinationType
          }
          promises.push snappiMessengerPluginService.getDataURLForAssetsByChunks_P(
              assets
              , options
              , (photo)->
                if options.DestinationType == CAMERA.DestinationType.FILE_URI 
                  imageCacheSvc.stashFile(photo.UUID, options.size, photo.data, photo.dataSize) # FILE_URI
                else 
                  self.dataURLs[options.size][photo.UUID] = photo.data
            ).then (photos)->
              return photos 

        return $q.all(promises).then (o)->
            # console.log "*** fetchPhotosFromQueueP $q All Done! \n" 
            return

      debounced_fetchPhotosFromQueue : ()->
        return console.log "\n\n\n ***** Placeholder: add debounce on init *********"


      ### #########################################################################
      # END methods for getting photos from cameraRoll, isDevice==true
      ### #########################################################################



      # getter, or reset queue
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



      # IMAGE_WIDTH should be computedWidth - 2 for borders
      getCollectionRepeatHeight : (photo, IMAGE_WIDTH)->
        if !IMAGE_WIDTH
          MAX_WIDTH = if deviceReady.device().isDevice then 320 else 640
          IMAGE_WIDTH = Math.min(deviceReady.contentWidth()-22, MAX_WIDTH)
        if !photo.scaledH || IMAGE_WIDTH != photo.scaledW
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

      # array of moments
      moments: []
      # orders
      orders: [] # order history
      state:
        photos:
          sort: null
          stale: false
    } # end cameraRoll

    self.debounced_fetchPhotosFromQueue = _.debounce self.fetchPhotosFromQueue
        , 1000
        , {
          leading: false
          trailing: true
          }

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
            # console.log ">>> callP returned for method=" + method + ", resp=" + JSON.stringify(resp)[0..100]
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
        # console.log "\n\n*** scheduleAssetsForUpload, data=\n" + JSON.stringify( data )
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


      mapCollectionsP: ()->
        # expecting [ {startDate: , endDate:, localizedTitle: , localizedLocationNames: , moments: [] , collectionListSubtype: , collectionListType: },{}]
        # moments = [ {startDate: , endDate:, localizedLocationNames: , "localizedTitle" , assetCollectionSubtype: ,assetCollectionType: ,assets: ,estimatedAssetCount: }, {} ]
        # console.log "mapCollections() calling window.Messenger.mapCollections(assets)"
        return deviceReady.waitP().then (retval)->
          dfd = $q.defer()
          return $q.reject "ERROR: window.Messenger Plugin not available" if !(window.Messenger?.mapCollections)
          # console.log "about to call Messenger.mapAssetsLibrary(), Messenger.properties=" + JSON.stringify _.keys window.Messenger.prototype 
          window.Messenger.mapCollections (mapped)->
              ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
              # attributes: UUID, dateTaken, mediaType, MediaSubTypes, hidden, favorite, originalWidth, originalHeight
              # console.log "\n *** mapAssetsLibrary Got it!!! length=" + mapped.length
              return dfd.resolve ( mapped )
            , (error)->
              return dfd.reject("ERROR: Messengerm.mapCollections(), msg=" + JSON.stringify error)
          # console.log "called Messenger.mapAssetsLibrary(), waiting for callbacks..."
          return dfd.promise

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
        options = _.defaults options || {} , {
          size: 'preview'
          DestinationType : CAMERA.DestinationType.FILE_URI 
        }
        return _MessengerPLUGIN.getPhotosByIdP(assets , options).then (photos)->
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

            # console.log "\n********** updated cameraRoll.dataURLs for this batch ***********\n"

            return photos
          , (errors)->
            console.warn "ERROR: getDataURLForAssetsByChunks_P", errors
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
              # console.log "\n\n>>>  $q.all() done, dataURLs for all chunks retrieved!, length=" + allPhotos.length + "\n\n"
              return allPhotos
            , (errors)->
              console.warn "ERROR: getDataURLForAssetsByChunks_P"
              console.warn errors  

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
          # console.log "\n\n>>>  SERIES fetch done, dataURLs for all chunks retrieved!, length=" + allPhotos.length + "\n\n"
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
        _.defaults options, defaults.preview if options.size=="preview"
        _.defaults options, defaults.thumbnail if options.size=="thumbnail"
        _.defaults options, defaults.previewHD if options.size=="previewHD"

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
              # console.log "\n>>>>>>>> window.Messenger.getPhotoById()  complete, count=" + retval.photos.length + " , elapsed=" + elapsed + "\n\n"
              return dfd.resolve ( retval.photos ) 
            else if retval.photos.length && retval.errors.length 
              # console.warn "WARNING: SOME errors occurred in Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
              # ???: how do we handle the errors? save them until last?
              return dfd.resolve ( retval.photos ) 
            else if retval.errors.length 
              console.warn "ERROR: Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
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
              if options.DestinationType == CAMERA.DestinationType.FILE_URI && photo.dataSize == 0
                console.warn "getPhotoById() Error, dataSize==0", _.pick photo, ['UUID', 'data', 'dataSize', 'dateTaken']

              # one callback for each element in assetIds
              end = new Date().getTime()
              ## expecting photo keys: [data,UUID,dateTaken,originalWidth,originalHeight]
              ## NOTE: extended attrs from mapAssetsLibrary: UUID, dateTaken, mediaType, MediaSubTypes, hidden, favorite, originalWidth, originalHeight
              # photo.elapsed = (end-start)/1000
              photo.from = 'cameraRoll'
              photo.autoRotate = options.autoRotate
              photo.orientation = _patchOrientation( photo )  # should be EXIF orientation

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

