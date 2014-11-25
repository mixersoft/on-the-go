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
              photo.elapsed = (end-start)/1000
              # TODO: need to get auto-rotate width/height from plugin
              photo.targetWidth = options.targetWidth
              photo.targetHeight = options.targetHeight
              photo.crop = options.resizeMode == 'aspectFill'
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
