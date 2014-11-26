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
    _cancel = null
    _timeout = 2000
    _device = null
    _isWebView = null 
    _deviceready = {
      deviceId: ()->
        return "browser" if !_deviceready.isWebView()
        return _device?.uuid

      isWebView: ()->
        return _isWebView
      waitP: ()->
        return _promise if _promise
        deferred = $q.defer()
        _cancel = $timeout ()->
            console.log "$ionicPlatform.ready NOT!!!"
            return deferred.reject("ERROR: ionicPlatform.ready does not respond")
          , _timeout
        $ionicPlatform.ready ()->
          # console.log "snappiAssetsPickerService reports $ionicPlatform.ready!!!"
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
  '$q', '$timeout', 'deviceReady', 
  'TEST_DATA', 'otgData', 'otgParse'
  ($q, $timeout, deviceReady, TEST_DATA, otgData, otgParse)->
    _getAsLocalTime : (d, asJSON=true)->
        d = new Date() if !d    # now
        throw "_getAsLocalTimeJSON: expecting a Date param" if !_.isDate(d)
        d.setHours(d.getHours() - d.getTimezoneOffset() / 60)
        return d.toJSON() if asJSON
        return d


    self = {
      # array of photos, use found = _.findWhere cameraRoll.photos, (UUID: uuid)
      # props: id->UUID, date, src, caption, rating, favorite, topPick, shared, exif
      #   plugin adds: dateTaken, origH, origW, height, width, crop, orientation,
      #   parse adds: assetId, from, createdAt, updatedAt
      photos: []
      dataURLs: {
        preview: {}     # indexBy UUID
        thumbnail: {}   # indexBy UUID
      }
      addPhoto: (photo)->
        console.warn "ERROR: photo.UUID 40 chars, iOS style, uuid=" + photo.UUID if photo.UUID.length > 36
        self.patchDateTaken(photo)
        self.photos.push photo
        # TODO: use _.indexAt by photo.dateTaken
        return self

      addDataURL: (size, photo)->
        # console.log "\n\n adding for size=" + size
        if !/preview|thumbnail/.test( size )
          return console.log "ERROR: invalid dataURL size, size=" + size
        console.log "WARNING: NOT truncating to UUID(36), deprecate!!" if photo.UUID.length > 36
        # console.log _.keys photo
        self.dataURLs[size][photo.UUID] = photo.data
        # console.log "\n\n added!! ************* " 
        return self

      # These 2 methods are temporary HACKS
      stashCameraRollMap: (map)->
        self._mapAssetsLibrary = _.clone map
      patchDateTaken: (photo)->
        return "WARNING: first stash cameraRoll map" if !self._mapAssetsLibrary
        # console.log "\n\n mapped=" + JSON.stringify self._mapAssetsLibrary

        found = _.find self._mapAssetsLibrary, {UUID: photo.UUID}
        console.log "\n\n patching with=" + JSON.stringify found
        photo.dateTaken = found?.dateTaken || null
        return photo.dateTaken

      getDateFromLocalTime : (dateTaken)->
        return null if !dateTaken
        if dateTaken.indexOf('+')>-1
          datetime = new Date(dateTaken) 
          # console.log "compare times: " + datetime + "==" +dateTaken
        else 
          # dateTaken contains no TZ info
          datetime = _getAsLocalTime(dateTaken, false) 

        datetime.setHours(0,0,0,0)
        date = self._getAsLocalTime( datetime, true)
        return date.substring(0,10)  # like "2014-07-14"
      getDataURL: (UUID, size='preview')->
        if !/preview|thumbnail/.test size
          throw "ERROR: invalid dataURL size, size=" + size
        return self.dataURLs[size][UUID]
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
        self.photos = otgData.parsePhotosFromMoments self.moments
        return

    return self
]
.factory 'snappiMessengerPluginService', [
  '$rootScope', '$q', 'cameraRoll'
  'snappiAssetsPickerService', 'deviceReady', 'appConsole', 'otgData'
  ($rootScope, $q, cameraRoll, snappiAssetsPickerService, deviceReady, appConsole, otgData)->
    _MessengerPLUGIN = {
      MAX_PHOTOS: 1000
      CHUNK_SIZE : 10
      SERIES_DELAY_MS: 100
      # methods for testing messenger plugin
      mapAssetsLibraryP: ()->
        console.log "mapAssetsLibrary() calling window.Messenger.mapAssetsLibrary(assets)"
        # return snappiAssetsPickerService.mapAssetsLibraryP();
        start = new Date().getTime()
        return snappiAssetsPickerService.mapAssetsLibraryP().then (mapped)->
            ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
            end = new Date().getTime()
            cameraRoll.stashCameraRollMap( mapped )
            photosByDate = otgData.mapDateTakenByDays(mapped, "like TEST_DATA")
            # returns: {2014-07-14:[{dateTaken: UUID: }, ]}
            retval = {
              elapsed : (end-start)/1000
              photos: photosByDate
              raw: mapped
            }
            return retval
          , (error)->
            appConsole.show( JSON.stringify error)
        .then (retval)->
          # replace cameraRoll.moments
          photos_inTestDataForm = {} # COPY!!
          _.each _.keys( retval.photos ) , (key)->
            photos_inTestDataForm[key] = _.map retval.photos[key], (o)->
              return o.UUID  # o.UUID[0...36]

          cameraRoll.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( photos_inTestDataForm ), 2
          # add to cameraRoll.photos in getDataURLForAssets_P()

          'skip' || _MessengerPLUGIN.replace_TEST_DATA(retval)

          appConsole.show( retval )
          return retval

      getDataURLForAssets_P: (assets, size)->
        # call getPhotosByIdP() with array
        return _MessengerPLUGIN.getPhotosByIdP( assets , size).then (photos)->
            
            _.each photos, (photo)->
              # merge into cameraRoll.dataUrls
              # keys:  UUID,data,elapsed, and more...
              # console.log "\n\n>>>>>>>  getPhotosByIdP(" + photo.UUID + "), DataURL[0..80]=" + photo.data[0..80]
              # cameraRoll.dataUrls[photo.format][ photo.UUID[0...36] ] = photo.data
              cameraRoll.addPhoto(photo)
              cameraRoll.addDataURL(photo.format, photo)
              console.log "\n*****************************\n"

            'skip' || _MessengerPLUGIN.replace_TEST_DATA_SRC photos  

            console.log "\n********** updated cameraRoll.dataURLs for this batch ***********\n"
            return photos
          , (errors)->
            console.log errors
            return $q.reject(errors)  # pass it on

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
          _.each chunks, (assets)->
            console.log "\n\none chunk of count=" + assets.length
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


        ## in Series, call recursively, no delay
        # allPhotos = []
        # getNextChunkInSERIES_P = (chunks)->
        #   assets = chunks.shift()
        #   return $q.reject("done") if !assets.length
        #   console.log "\n\none chunk of count=" + assets.length + ", remaining chunks=" + chunks.length
        #   return _MessengerPLUGIN.getDataURLForAssets_P( assets  , size).then (chunkOfPhotos)->


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


      getPhotosByIdP: (assets, size = 'preview')->
        # takes asset OR array of assets
        options = {type: size} if _.isString size
        return snappiAssetsPickerService.getAssetsByIdP(assets, options)

      getDataURLForAllPhotos_PARALLEL_snappiAssetsPicker_P : (raw)->
        # install snappiAssetsPicker plugin!!!
        # load dataURLs for assets
        assets = _.clone raw
        cameraRoll.dataUrls = {}
        promises = []
        _.each assets, (asset)->
          label = 'preview' # [preview | thumbnail]
          uuidExt = asset.UUID[0...36] + '.JPG' 
          console.log ">>>>>>>  Here in _.each, uuidExt=" + uuidExt
          promise = snappiAssetsPickerService.getAssetByIdP_snappiAssetsPicker(uuidExt, {}, null, label).then (photo)->
              console.log ">>>>>>>  getPhotosByIdP(" + photo.uuid + "), DataURL[0..20]=" + photo.data[label][0..20]
              cameraRoll.dataUrls[ photo.uuid ] = photo.data[label]
              console.log "*****************************"
              return photo
            , (error)->
              console.log error
          
          promises.push(promise)
          return true

        return $q.all(promises).then (photos)->
          console.log ">>>>>>>>>  $q.all dataUrls retrieved!  ***"
          return photos   

      replace_TEST_DATA: (retval)->
        photos_AsTestData = {} # COPY!!
        _.each _.keys( retval.photos ) , (key)->
          photos_AsTestData[key] = _.map retval.photos[key], (o)->
            return o.UUID[0...36]

        serverPhotos = _.filter cameraRoll.photos, {from: "PARSE"}
        console.log "\n\n****** keeping serverPhotos, count=" + serverPhotos.length + "\n\n"

        TEST_DATA.cameraRoll_byDate = photos_AsTestData  
        cameraRoll.photos_ByDate = TEST_DATA.cameraRoll_byDate
        cameraRoll.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( cameraRoll.photos_ByDate ), 2
        cameraRoll.photos = otgData.parsePhotosFromMoments cameraRoll.moments
        # TODO: MERGE o.dateTaken into photos !!!

        console.log "\n\n****** merging serverPhotos, count=" + serverPhotos.length + "\n\n"
        _.each serverPhotos, (o)->
          found = _.find cameraRoll.photos, {id: o.id}
          return console.log " ???  can't find id="+o.id if !found
          _.extend found, _.pick o, ['topPick', 'favorite']
          return console.log "\n\n !!!!! copy topPick, favorite for id="+o.id + ", found.topPick=" + found.topPick

        'DEPRECATED' || otgWorkOrder.setMoments(cameraRoll.moments)

         # add some test data for favorite and shared
        TEST_DATA.addSomeTopPicks( cameraRoll.photos)
        TEST_DATA.addSomeFavorites( cameraRoll.photos)
        TEST_DATA.addSomeShared( cameraRoll.photos)
        _.extend window.debug , cameraRoll

      replace_TEST_DATA_SRC : (photos)->
        _.each photos, (photo, i)-> 
          UUID = photo.UUID[0...36]
          e = _.find cameraRoll.photos, {id: UUID }
          return console.log "  !!!!!!!!!!!!   replace_TEST_DATA_SRC: not found, UUID="+UUID if !e
          e.height = if photo.crop then photo.targetHeight else 240
          e.src = _MessengerPLUGIN.getDataUrlFromUUID(UUID)
          # e.topPick = true          ## debug only !!!
          e.getSrc = _MessengerPLUGIN.getDataUrlFromUUID
          console.log "\n\n ##############   asset.id=" + e.id + "\ndataURL[0...20]=" + e.src[0...20]
          return


      getDataUrlFromUUID : (UUID)->
        return cameraRoll.dataUrls?[ UUID ]

      OLD_testMessengerPlugin: ()->
        console.log "testing testMessengerPlugin...."
        return snappiAssetsPickerService.mapAssetsLibraryP().then (mapped)->
            # console.log "mapped.length=" + mapped.length + ", first 3 items to follow:"
            # console.log JSON.stringify mapped[0..3]
            ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
            asset = mapped[0]
            return _MessengerPLUGIN.getPhotoByIdP(asset, 320, 240).then (photo)->
                # console.log "getPhotoByIdP(" + asset.UUID + "), DataURL[0..20]=" + photo.data[0..20]
                return {
                    count: mapped.length
                    sample: mapped[0..5]
                    samplePhoto: 
                      UUID: photo.UUID
                      dataURL: photo.data[0..100]
                  }
              , (error)->
                return console.error error


    }
    return _MessengerPLUGIN
]
.factory 'snappiAssetsPickerService', [
  '$q', '$ionicPlatform', '$timeout', '$rootScope'
  'PLUGIN_CAMERA_CONSTANTS', 'assetsPickerCFG'
  ($q, $ionicPlatform, $timeout, $rootScope, CAMERA, CFG)->  
    _defaultCameraOptions = {
        fromPhotoLibrary:
          quality: CFG.camera.quality
          # destinationType: CFG.Camera.DestinationType.FILE_URI
          destinationType: CAMERA.DestinationType.DATA_URL
          sourceType: CAMERA.PictureSourceType.PHOTOLIBRARY
          correctOrientation: true # Let Cordova correct the picture orientation (WebViews don't read EXIF data properly)
          targetWidth: CFG.camera.targetWidth
          # thumbnail: true
          popoverOptions: 
              x: 268
              y: 0
              width: 500
              height: 400
              popoverWidth: 500
              popoverHeight: 624
              arrowDir: CAMERA.PopoverArrowDirection.ARROW_UP
          # iPad camera roll popover position
            # width: 768
            # height: 
            # arrowDir: CAMERA.PopoverArrowDirection.ARROW_UP
        fromCamera:
          quality: CFG.camera.quality
          destinationType: CAMERA.DestinationType.IMAGE_URI
          correctOrientation: true
          targetWidth: CFG.camera.targetWidth
    }

    # wrap $ionicPlatoform ready in a promise, borrowed from otgParse
    _deviceready = {
      promise : null
      cancel: null
      timeout: 5000
      check: ()->
        return _deviceready.promise if _deviceready.promise
        deferred = $q.defer()
        _deviceready.cancel = $timeout ()->
            console.log "$ionicPlatform.ready NOT!!!"
            return deferred.reject("ERROR: ionicPlatform.ready does not respond")
          , _deviceready.timeout
        $ionicPlatform.ready ()->
          # console.log "snappiAssetsPickerService reports $ionicPlatform.ready!!!"
          $timeout.cancel _deviceready.cancel
          # $rootScope.deviceId = $cordovaDevice.getUUID()
          device = ionic.Platform.device()
          $rootScope.deviceId = device.uuid if device.uuid
          console.log "$ionicPlatform reports deviceready, device.UUID=" + $rootScope.deviceId
          return deferred.resolve("deviceready")
        return _deviceready.promise = deferred.promise
    }

    _getAsLocalTimeJSON = (d)->
        d = new Date() if !d
        throw "_getAsLocalTimeJSON: expecting a Date param" if !_.isDate(d)
        d.setHours(d.getHours() - d.getTimezoneOffset() / 60)
        return d.toJSON()

    self = {
      deviceReadyP: _deviceready.check
      mapAssetsLibraryP: (options = {})->

        defaults = {
          pluck: ['DateTimeOriginal', 'PixelXDimension', 'PixelYDimension', 'Orientation']
          fromDate: '2014-09-01'
          toDate: null
        }

        options = _.defaults options, defaults
        options.fromDate = _getAsLocalTimeJSON(options.fromDate) if _.isDate(options.fromDate)
        options.toDate = _getAsLocalTimeJSON(options.toDate) if _.isDate(options.toDate)


        self.deviceReadyP().then (retval)->
          # console.log "deviceReadyP, retval="+retval
          dfd = $q.defer()
          start = new Date().getTime()
          return $q.reject "ERROR: window.Messenger Plugin not available" if !(window.Messenger?.mapAssetsLibrary)
          console.log "about to call Messenger.mapAssetsLibrary(), Messenger.properties=" + JSON.stringify _.keys window.Messenger.prototype 
          window.Messenger.mapAssetsLibrary (mapped)->
              ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
              end = new Date().getTime()
              console.log "\n\n*** window.Messenger.mapAssetsLibrary() success!! *** elapsed=" + (end-start)/1000 + "\n\n"
              return dfd.resolve ( mapped )
            , (error)->
              return dfd.reject("ERROR: MessengermapAssetsLibrary(), msg=" + JSON.stringify error)
          # console.log "called Messenger.mapAssetsLibrary(), waiting for callbacks..."
          return dfd.promise

      getAssetsByIdP: (assets, options)->
        defaults = {
          preview: 
            targetWidth: 640
            targetHeight: 640
            resizeMode: 'aspectFit'
          previewHD: 
            targetWidth: 1080
            targetHeight: 1080
            resizeMode: 'aspectFit'
          thumbnail:
            targetWidth: 64
            targetHeight: 64
            resizeMode: 'aspectFill'
        }
        options = _.extend options, defaults.preview if options.type=="preview" || !(options?.type)
        options = _.extend options, defaults.thumbnail if options.type=="thumbnail"
        options = _.extend options, defaults.previewHD if options.type=="previewHD"
        
        assets = [assets] if !_.isArray(assets)
        assetIds = _.pluck assets, 'UUID'

        # console.log "\n>>>>>>>>> snappiAssetsPickerService: assetIds=" + JSON.stringify assetIds 
        # console.log "\n>>>>>>>>> snappiAssetsPickerService: options=" + JSON.stringify options

        self.deviceReadyP().then (retval)->
          # console.log "deviceReadyP, retval="+retval
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
            if remaining == 0
              if retval.errors.length == 0
                console.log "\n>>>>>>>> window.Messenger.getPhotoById()  complete, count=" + retval.photos.length + " \n\n"
                return dfd.resolve ( retval.photos ) 
              else if retval.photos.length && retval.errors.length 
                console.log "WARNING: SOME errors occurred in Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
                return dfd.resolve ( retval.photos ) 
              else if retval.errors.length 
                return dfd.reject "ERROR: Messenger.getPhotoById(), errors=" + JSON.stringify retval.errors
            return



          window.Messenger.getPhotoById assetIds, options, (photo)->
              # one callback for each element in assetIds
              end = new Date().getTime()
              # props: UUID, dataURL
              photo.elapsed = (end-start)/1000
              # TODO: need to get auto-rotate width/height from plugin
              photo.orientation = null
              photo.origW = null
              photo.origH = null
              photo.dateTaken = null

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
              console.log error
              retval.errors.push error
              remaining -= 1
              return _resolveIfDone(remaining, retval, dfd)

          return dfd.promise

      mapAssetsLibraryP_snappiAssetsPicker: (options = {})->

        defaults = {
          pluck: ['DateTimeOriginal', 'PixelXDimension', 'PixelYDimension', 'Orientation']
          fromDate: '2014-09-01'
          toDate: null
        }

        options = _.defaults options, defaults
        options.fromDate = _getAsLocalTimeJSON(options.fromDate) if _.isDate(options.fromDate)
        options.toDate = _getAsLocalTimeJSON(options.toDate) if _.isDate(options.toDate)
        self.deviceReadyP().then (retval)->
          console.log "deviceReadyP, retval="+retval
          dfd = $q.defer()
          start = new Date().getTime()
          return console.error "ERROR: Plugin not available" if !(window.plugin?.snappi?.assetspicker?.mapAssetsLibrary)
          console.log "about to call mapAssetsLibrary, options=" + JSON.stringify options
          window.plugin.snappi.assetspicker.mapAssetsLibrary (mapped)->
              end = new Date().getTime()
              mapped.elapsed = (end-start)/1000
              console.log '*** mapped.lastDate='+mapped.lastDate + ', count='+mapped.assets.length + ', elapsed=' + mapped.elapsed
              console.log JSON.stringify mapped.assets[-20..-1]
              return dfd.resolve ( mapped )
            , (error)->
              return dfd.reject("ERROR: mapAssetsLibrary(), msg=" + JSON.stringify error)
            , options
          return dfd.promise

      getAssetByIdP_snappiAssetsPicker: (o, options={}, extension='JPG', label='preview')->
        ### 
        expecting o = { // from mapAssetsLibrary()
          uuid:
          orig_ext: 
        }

        resolve with o = {
          uuid:
          orig_ext:
          dataURL:
            [label]: [dataURL]
        }
        ###
        options = _.defaults options, CFG.camera
        options.destinationType = CAMERA.DestinationType.DATA_URL # force!
        options.thumbnail = true if label=='thumbnail'

        if extension == 'PNG' 
          options.encodingType = CAMERA.EncodingType.PNG 
          options.mimeType = 'image/png'
        else 
          options.encodingType = CAMERA.EncodingType.JPEG
          options.mimeType = 'image/jpeg'

        self.deviceReadyP().then ()->
          dfd = $q.defer()
          start = new Date().getTime()
          return console.error "ERROR: Plugin not available" if !window.plugin?.snappi?.assetspicker
          console.log "about to call getAssetByIdP, options=" + JSON.stringify options
          window.plugin.snappi.assetspicker.getById o.uuid
            , o.orig_ext
            , (data)->
              o.dataURL = o.dataURL || {}
              o.elapsed = (end-start)/1000
              o.dataURL[label] = "data:" + options.mimeType + ";base64," + data.data
              console.log "getPreviewAsDataURL(): getById() for DATA_URL, label=" + label + ", data="+o.dataURL[label][0..100]
              return dfd.resolve o
            , (error)->
              dfd.reject("Error assetspicker.getbyId() to dataURL, error=" + JSON.stringify error )
            , options
          return dfd.promise 

      getPictureP: (options={})->
        console.log "snappiAssetsPickerService.getPictureP()"
        ### 
        ###
        options = _.defaults options, CFG.camera
        options.destinationType = CAMERA.DestinationType.DATA_URL # force!


        self.deviceReadyP().then ()->
          dfd = $q.defer()
          start = new Date().getTime()
          return console.error "ERROR: Plugin not available" if !window.plugin?.snappi?.assetspicker
          window.plugin.snappi.assetspicker.getPicture (dataArray)->
              console.log "getPicture success"
              _.each dataArray, (o)->
                ###
                expecting: o = {
                  id : ALAssetsLibrary Id, assets-library://asset/asset.{ext}?id={uuid}&ext={ext}
                  uuid : uuid,
                  label: string
                  orig_ext : orig_ext, [JPG | PNG] NOT same as options.encodingType
                  data : String, File_URI: path or Data_URL:base64-encoded string
                  exif : {
                      DateTimeOriginal : dateTimeOriginal,  format:  "yyyy-MM-dd HH:mm:ss"
                      PixelXDimension : pixelXDimension, 
                      PixelYDimension : pixelYDimension,
                      Orientation : orientation
                  };
                ### 
                console.log _.pick o, ['id', 'uuid', 'orig_ext', 'exif']
                console.log "DATA_URL, label=" + o.label + ", dataURL="+o.data[0..100]
              return dfd.resolve o
            , (error)->
              dfd.reject("Error assetspicker.getPicture(), error=" + JSON.stringify error )
            , options
          return dfd.promise     

    }

    return self;
]
