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
          console.log "about to call Messenger.mapAssetsLibrary(), options=" + JSON.stringify options
          window.Messenger.mapAssetsLibrary (mapped)->
              console.log "*** window.Messenger.mapAssetsLibrary success!! ***"
              return dfd.resolve ( mapped )
            , (error)->
              return dfd.reject("ERROR: MessengermapAssetsLibrary(), msg=" + JSON.stringify error)
            , options
          return dfd.promise
      getAssetByIdP: (asset, w, h)->
        self.deviceReadyP().then (retval)->
          # console.log "deviceReadyP, retval="+retval
          dfd = $q.defer()
          start = new Date().getTime()
          return $q.reject "ERROR: window.Messenger Plugin not available" if !(window.Messenger?.getPhotoById)
          window.Messenger.getPhotoById testAsset.UUID, w, h, (photo)->
              console.log "*** window.Messenger.getPhotoById success!! ***"
              console.log _.keys photo
              return dfd.resolve ( photo )
            , (error)->
              console.log error
              return dfd.reject("ERROR: Messenger.getPhotoById(), msg=" + JSON.stringify error)
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
