'use strict'

###*
 # @ngdoc factory
 # @name onTheGo.localStorage
 # @description 
 # methods for local storage, including caching DataURLs and remote img URLs
 # 
###

# ng-cordova patch: for Chrome browser testing
window.requestFileSystem = window.requestFileSystem || window.webkitRequestFileSystem
#

angular
.module 'onTheGo.localStorage', ['ngStorage']

.service 'otgLocalStorage', ['$q', '$localStorage', '$sessionStorage'
  ($q, $localStorage, $sessionStorage)->
    # TODO: load from REST API or Parse Config svc
    self = this
    this.defaults = {
      device:
        id: null
        platform: {}
        isDevice: null
        isBrowser: null
        pushInstall: null
      config: # default app config params
        'app-bootstrap' : true
        'no-view-headers' : false
        'system':
          'order-standby': false
        help: false
        privacy:
          'only-mothers': false
        upload:
          'auto-upload': false
          'use-cellular-data': false
          'use-720p-service': true
          'CHUNKSIZE': 10
        archive:
          'copy-top-picks': false
          'copy-favorites': false  
        sharing:  
          'use-720p-sharing': false
        'dont-show-again':
          'test-drive': false
          'top-picks':
            'top-picks': false
            'favorite': false
            'shared': false
          choose:
            'camera-roll': false
            calendar: false
          'workorders':
            'photos': false
            'todo' : false
            'picks' : false
      menuCounts: 
        'top-picks': 0
        uploaderRemaining: 0
        orders: 0
      topPicks:
        showInfo: true
        counts:
          'top-picks': null
          favorites: null
          shared: null 
      cameraRoll:
        map: []       
      # used by imageCacheSvc
      fileURI_Cache: {}
      fileURI_Archive: {}
      fileURI_MostRecent : []
        # TODO: organize cache by image size
    }
    this.loadDefaults = (keys, storage='local')->
      keys = [keys] if _.isString keys
      $storage = if storage == 'session' then $sessionStorage else $localStorage
      _.each keys, (key)->
        return if !self.defaults[key]?
        return $storage[key] = self.defaults[key]

    this.loadDefaultsIfEmpty = (keys, storage='local')->
      keys = [keys] if _.isString keys
      $storage = if storage == 'session' then $sessionStorage else $localStorage
      _.each keys, (key)->
        return if !self.defaults[key]?
        return if $storage[key]?
        return $storage[key] = self.defaults[key]

    this.defer = (key, fnDefer)->
      orig = $localStorage[key] 
      _copy = angular.copy orig
      # console.log "\n\n @@@@ localStorage deferred updates"
      _copy = fnDefer(_copy)
      return $localStorage[key] = _copy

    this.clear = (storage='local')->
      keys = [keys] if _.isString keys
      $storage = if storage == 'session' then $sessionStorage else $localStorage
      _.each keys, (key)->
        return if !self.defaults[key]?
        return $storage[key] = {}

    this.reset = (storage='local')->
      this.clear()
      _.each _.keys( this.defaults ), (key)->
        return $storage[key] = self.defaults[key]

    return
  ]

.factory 'imageCacheSvc', [
  '$q', '$timeout',  'deviceReady', '$cordovaFile', 
  '$localStorage', '$sessionStorage', 'otgLocalStorage'
  ($q, $timeout, deviceReady, $cordovaFile, $localStorage, $sessionStorage, otgLocalStorage)->
    _promise = null
    _timeout = 2000

    XXX_IMAGE_CACHE_defaults = {
      chromeQuota: 50*1024*1024 # HTML5 FILE API not available for Safari, check cordova???
      debug: true
      skipURIencoding: true    # required for dataURLs
      usePersistentCache: false
    }

    _dataURItoBlob = (dataURI)-> 
      #convert base64 to raw binary data held in a string
      base64raw = dataURI.split(',')[1]
      base64raw = base64raw.replace(/\s/g, '');
      byteString = atob(base64raw)

      #separate out the mime component
      mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0]

      #write the bytes of the string to an ArrayBuffer
      arrayBuffer = new ArrayBuffer(byteString.length)
      _ia = new Uint8Array(arrayBuffer);
      
      _ia[i] = byteString.charCodeAt(i) for i in [0..byteString.length]

      dataView = new DataView(arrayBuffer)
      try 
        # console.log("$$$ Private.dataURItoBlob BEFORE new Blob")
        blob = new Blob([dataView], { type: mimeString })
        # console.log("$$$ Private.dataURItoBlob AFTER new Blob")
        return blob;
      catch err
        console.warn('ERROR: Blob support not available for dataURItoBlob')
      return false


    # _.extend ImgCache.options, XXX_IMAGE_CACHE_defaults

    # deviceReady.waitP().then ()->
    #   ImgCache.init()

    _bytesToSize = (bytes)-> 
       return '0 Byte' if (bytes == 0) 
       k = 1000;
       sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
       i = Math.floor(Math.log(bytes) / Math.log(k));
       return (bytes / Math.pow(k, i)).toPrecision(3) + ' ' + sizes[i];

    otgLocalStorage.loadDefaultsIfEmpty(['fileURI_Cache','fileURI_MostRecent']) 

    ##
    ## imageCacheSvc
    ##
    self = {
      # index of cached files by UUID
      cacheIndex : $localStorage['fileURI_Cache'] 
      archiveIndex: $localStorage['fileURI_Archive'] # for saved favorites
      # stack for garbage collection, mostRecently used UUID on the 'top'
      # use copy and update $localStorage['fileURI_MostRecent'] in debounced method
      mostRecent : angular.copy $localStorage['fileURI_MostRecent'] 

      ##
      # IMPORTANT: map $cordovaFile dir to Plugin FILE_URI dir
      ##
      PLUGIN_DIR: 'Library/files' # Messenger writes to this folder
      PLUGIN_ROOT: null  # cordova.file.applicationStorageDirectory, set in $ionicPlatform.ready
      # $cordovaFile.writeFile('/'+...) writes to ./Library/files == PLUGIN_DIR
      CACHE_DIR : '/' # => cordova.file.applicationStorageDirectory + Library/files
      CACHE_ROOT : null  # dirEntry, (NOT path), set in $ionicPlatform.ready

      LIMITS:
        MAX_PREVIEW: 500
        MOST_RECENT: 1000 # apply _.unique on reaching limit

      SIZE_LOOKUP :
        'thumbnail':64
        'preview':320
        'preview@2x':750
        'previewHD':1080

      isDataURL : (src)->
        return false if typeof src != 'string'
        return /^data:image/.test( src )

      getDataURLExt: (dataURL)->
        return if !self.isDataURL(dataURL)
        mimeType = dataURL[10..20]
        return 'jpg' if /jpg|jpeg/i.test(mimeType)
        return 'png' if /png/i.test(mimeType)
        return 

      getFilename: (UUID, size, dataURL)->
        # Follows the naming convention of Plugin FILE_URI
        filenameBase = UUID.replace('/','~')
        size = self.SIZE_LOOKUP[size] if self.SIZE_LOOKUP[size]
        size = size || 'unknown'
        if !dataURL
          return filePath = filenameBase + '~' + size + '.jpg'
        # else
        ext = self.getDataURLExt(dataURL) 
        return false if !ext || !filenameBase
        return filePath = filenameBase + '~' + size + '.' + ext

      # for parsing files written by Plugin FILE_URI, example: 
      #     FDD10266-CE34-44E4-886F-E10A408E1483~L0~001~720.jpg
      #     FDDFF97C-63E1-44BA-B803-59C5A0A7292A~L0~001~64.jpg
      getHashKeyFromFilename: (filename)->
        # the inverse of self.getFilename()
        # TODO: this will NOT work with PLUGIN FileURIs, need to persist stashFile to local storage
        parts = filename.split('~')
        tail = parts.pop() # 64.jpg
        ext = tail.split('.').pop()
        size = if tail.length == 0 then "unknown" else tail[0]
        UUID = parts.join('-')
        return self.getHashKey(UUID, size)

      getHashKey: (UUID,size)->
        size = self.SIZE_LOOKUP[size] if self.SIZE_LOOKUP[size]
        size = size || 'unknown'
        return hashKey = [ UUID[0...36] , size].join(':') 

      debounced_MostRecent: _.debounce ()->
          self.mostRecent = _.unique(self.mostRecent)
          $localStorage['fileURI_MostRecent'] = self.mostRecent
          if self.mostRecent.length >  self.LIMITS.MOST_RECENT
            self.clearStashedP('preview', self.LIMITS.MAX_PREVIEW, 'appCache')          
          return
        , 5000 # 5*60*1000
        , {
          leading: true
          trailing: false
        }

      # NOTE: this 'fast' version called by camera.getPhoto
      ###
      # @return stashed object, {fileURL:, fileSize:} or false
      ###
      isStashed:  (UUID, size, repo='appCache')-> 
        CACHE_ROOT = cordova.file.applicationStorageDirectory
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        hashKey = self.getHashKey( UUID, size)
        stashed = self[stashKey][hashKey] || null
        match = self.PLUGIN_ROOT.slice(7)
        if stashed?.fileURL.indexOf(match) == 0
          # console.log "\n\n >>> STASH HIT !!!  file=" + src.slice(-60) 
          self.mostRecent.unshift(hashKey)
          self.debounced_MostRecent()
        else if stashed?.fileURL
          console.log "\n>>> STASH hit STALE, file=" + stashed.fileURL 
          self.clearStashKey(UUID, size)
          stashed = false
        else 
          stashed = false
        return stashed

      isStashed_P:  (UUID, size)->
        stashed = self.isStashed UUID, size
        return $q.when (stashed) if stashed        
        return $q.reject('WARN: isStashed_P() unable to guess valid filePath for ' + [UUID,size].join(':') ) 
        # TODO: cordovaFile_CHECK_P() when we can guess filePath for FILE_URIs
        return self.cordovaFile_CHECK_P(UUID, size, null)

      stashFile: (UUID, size, fileURL, fileSize, repo='appCache')->
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        if !size
          filename = fileURL.split('/').pop()
          hashkey = self.getHashKeyFromFilename(filename)
        else 
          hashKey = self.getHashKey( UUID, size)
        # console.log "\n\n >>> STASH file=" + hashKey + ", url=" + fileURL
        self[stashKey][hashKey] = {
          fileURL: fileURL
          fileSize: fileSize
        }

      stashSize: (repo='appCache')->
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        total = _.reduce self[stashKey], (total, o)->
            return total += o.fileSize || 0
          , 0
        return total

      stashStats: (repo='appCache')->
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        return {
          size: _bytesToSize( self.stashSize(repo) )
          count: _.values( self[stashKey] ).length
        }


      unstashFileP: (UUID, size, defer = false, repo='appCache')->
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        hashKey = self.getHashKey( UUID, size)
        o = self[stashKey][hashKey]
        return $q.reject("stashFile not found") if !o
        filename = self.CACHE_DIR + o.fileURL.split('/').pop()
        # console.log "remove o.fileURL="+o.fileURL.slice(-60)+", filename="+filename
        return $cordovaFile.removeFile(filename).then (retval)->
            # console.log ">>> $cordovaFile.removeFile complete, filename=" + filename.slice(-60)
            # console.log retval # $$$
            return hashKey if defer
            self.clearStashKey UUID, size, repo
            delete self[stashKey][ hashKey ]
            return
          , (err)->
            if err.code == 1 # NOT FOUND
              # console.log ">>> $cordovaFile.removeFile NOT FOUND, filename=" + filename.slice(-60)
            else 
              console.warn ">>> $cordovaFile.removeFile error", [err, filename.slice(-60)]
            return hashKey if defer
            self.clearStashKey UUID, size, repo
            return
      
      clearStashKey:(UUID, size, repo='appCache')->
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        hashKey = self.getHashKey( UUID, size)
        delete self[stashKey][ hashKey ]
        return

      ## @param type string, [preview|thumbnail], keep = count 
      clearStashedP: (type, keep, repo='appCache')->
        stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
        $timeout ()->
            # console.log "\n\n *** clearStashedP() begin, size="+self.stashSize(repo)
            promises = []

            if keep && type && repo=='appCache'
              keyOfType = _.filter self.mostRecent, (hashKey)->
                return hashKey.indexOf(type) > -1
              hashKeys = keyOfType.slice keep
            else if keep && repo=='appCache'
              hashKeys = self.mostRecent.slice keep
            else 
              hashKeys = _.keys self[stashKey]

            _.each hashKeys, (hashKey)->
              return if type && hashKey.indexOf(type) == -1
              promises.push self.unstashFileP(hashKey, null, 'defer', repo)
            return $q.all(promises).then (hashKeys)->
              # make changes to self[stashKey] outside of $localStorage $watch
              localStorageKey = if repo == 'appCache' then 'fileURI_Cache' else 'fileURI_Archive'
              self[stashKey] = otgLocalStorage.defer localStorageKey, (o)->
                # update mostRecent, persist on next debounce
                self.mostRecent = _.difference self.mostRecent, hashKeys if repo=='appCache'
                # update sacheIndex
                return _.omit o, hashKeys 

              self.mostRecent = self.mostRecent.slice(0,keep) if keep && repo=='appCache'
              # console.log "*** clearStashedP() END, size="+self.stashSize(repo)
          , 100

      # filter cache to remove all entries that are outside basepath
      #   this usually occurs during app testing or re-install
      # usage: self.filterStashed( self.PLUGIN_ROOT )
      filterStashed: (basepath, repo='appCache')->
        $timeout ()->
            stashKey = if repo == 'appCache' then 'cacheIndex' else 'archiveIndex'
            match = self.PLUGIN_ROOT.slice(7)
            _.each self[stashKey], (v,k)->
              return if v.fileURL?.indexOf( match ) == 0
              delete self[stashKey][k]
              return
            console.log "imgCacheSvc.filterStashed() complete"
            return
          , 5000
        return

      cordovaFile_LOAD_CACHED_P : (dirEntry)->
        # cordova.file.cacheDirectory : ./Library/Caches
        # cordova.file.documentsDirectory : ./Library/Documents
        # cordova.file.applicationStorageDirectory => ./Library

        dirEntry = self.CACHE_ROOT if !dirEntry

        dfd = $q.defer()
        fsReader = dirEntry.createReader()
        fsReader.readEntries (entries)->
            filenames = []
            promises = []
            _.each entries, (file)->
              return if !file.isFile

              fileURL = file.nativeURL || file.toURL()
              promises.push self.getMetaData_P(file).then (meta)->
                fileSize = meta.size
                self.stashFile( null, null, fileURL, fileSize)
                console.log "\n @@@load> " + UUID + '-' + size + ' : '+ fileURL.slice(-68)
                return fileSize

              filenames.push file.name
              return
            console.log "\n\n *** cordovaFile_LOAD_CACHED_P cached. file count=" + filenames.length
            console.log filenames # $$$  
            return $q.all(promises).then (sizes)->
              return dfd.resolve(filenames)
          , (err)->
            console.warn "ERROR: cordovaFile_LOAD_CACHED_P" + JSON.stringify err # $$$
            dfd.reject( "ERROR: reading directory entries")

        return dfd.promise
    

      getMetaData_P: (file)->
        throw "ERROR: expecting fileEntry" if !file.file
        dfd = $q.defer()
        file.file ( metaData )->
            return dfd.resolve _.pick metaData, ['name', 'size', 'lastModified', 'localURL']
          , (errors)->
            console.log error # $$$
            dfd.reject( "ERROR: reading fileEntry metaData")
        return dfd.promise


      cordovaFile_CHECK_P: (UUID, size, dataURL)->
        filePath = self.getFilename(UUID, size, dataURL)
        if !filePath 
          promise = $q.reject('ERROR: cordovaFile_CHECK_P() unable to get valid Filename for ' + [UUID,size].join(':') ) 
        else 
          promise = $cordovaFile.checkFile( self.CACHE_DIR + filePath )

        return promise.catch (error)->
          if error instanceof FileError && error.code == 1 # file not found
            console.warn "$ngCordovaFile.checkFile() says DOES NOT EXIST, file=", filePath 
            # debug
            cameraRoll = window.debug.cameraRoll
            photo = _.find cameraRoll.map(), {UUID:UUID}
            console.warn "photo=", photo
          self.clearStashKey UUID, size
          return $q.reject(error)
        .then (file)->
          ### example {
            "name":"AC072879-DA36-4A56-8A04-4D467C878877-thumbnail.jpg",
            "fullPath":"/AC072879-DA36-4A56-8A04-4D467C878877-thumbnail.jpg",
            "filesystem":"<FileSystem: persistent>",
            "nativeURL":"file:///Users/.../Library/Developer/CoreSimulator/Devices/596BAB03-FCAE-46C4-B3C8-8100ECD66EDF/data/Containers/Data/Application/B95C85A8-0D75-4AEE-94B0-BA79525C71B3/Library/files/AC072879-DA36-4A56-8A04-4D467C878877-thumbnail.jpg"
          ###
          # console.log file  # $$$ _.keys == {name: fullPath: filesystem: nativeURL: }
          # console.log "$ngCordovaFile.checkFile() says file EXISTS file=" + file.nativeURL + "\n\n"

          # stash, if necessary
          ### example chrome/HTML5 FileEntry
            filesystem: DOMFileSystem
            fullpath: "/[UUID].jpg"
            isDirectory: false
            isFile: true
            name: [UUID].jpg
            toURLfile()
            getParent( ? )
            getMetaData( ? ) 
            # get directory
          ###

          ### example iOS FileEntry ???
            filesystem:
              name: 'persistent'
              root: 
                nativeURL: "file:///Users/[username]/Library/Developer/CoreSimulator/Devices/[App-UUID]/data/Containers/Data/Application/[UUID]/Library/files/"
            fullpath: "/[UUID].jpg"
            isDirectory: false
            isFile: true
            name: [UUID].jpg
            nativeURL: "file:///Users/[username]/Library/Developer/CoreSimulator/Devices/[App-UUID]/data/Containers/Data/Application/[UUID]/Library/files/[UUID].jpg"
            getParent( ? )
            getMetaData( ? ) 
            # get directory
          ###

          fileURL = file.nativeURL || file.toURL()
          return self.getMetaData_P(file).then (meta)->
            fileSize = meta.size
            self.stashFile UUID, size, fileURL, fileSize
            return fileURL
        .catch (error)->
          if error instanceof FileError && error.code == 1 # file not found
            return $q.reject(error)

          console.warn 'cordovaFile_CHECK_P', error 
          return $q.reject(error)


      cordovaFile_WRITE_P: (UUID, size, dataURL)->
        filePath = self.getFilename(UUID, size, dataURL)
        return $q.reject('ERROR: unable to get valid Filename') if !filePath
        
        try
          blob = _dataURItoBlob(dataURL)
        catch error
          console.warn "error: cordovaFile_WRITE_P="+ dataURL[0...100]
          console.warn error

        # console.log "\n >>> $ngCordovaFile.writeFile() for file=" + filePath
        return $cordovaFile.writeFile( self.CACHE_DIR + filePath, blob, {'append': false} )
        .then (ProgressEvent)->
            # check ProgressEvent.target.length, ProgressEvent.target.localURL
            # console.log "$ngCordovaFile writeFile SUCCESS"
            retval = {
              filePath: filePath
              fileSize: ProgressEvent.target.length
              localURL: ProgressEvent.target.localURL
            }
            # console.log retval # $$$
            return retval
        .catch (error)->
            console.warn "$ngCordovaFile writeFile ERROR"
            console.warn error # $$$
            return $q.reject(error)
        .then (retval)->
          fileSize = retval.fileSize
          filePath = retval.filePath
          return $cordovaFile.checkFile( self.CACHE_DIR + filePath ).then (file)->
            # console.log file  # $$$ _.keys == {name:, fullPath:, filesystem:, nativeURL: }
            # console.log "$ngCordovaFile.checkFile() says file EXISTS file=" + file.nativeURL + "\n\n"
            return {
              fileURL: file.nativeURL
              fileSize: fileSize
            }


      # will overwrite cached file, use cordovaFile_CHECK_P() if not desired
      # @param UUIDs array, will convert single UUID to array
      cordovaFile_CACHE_P: (UUID, size, dataURL)->
        # console.log "\n\n$$$ cordovaFile_CACHE_P, UUID="+UUID
        return self.cordovaFile_WRITE_P(UUID, size, dataURL)
        .then (retval)->
          # console.log retval # $$$
          self.stashFile(UUID, size, retval.fileURL, retval.fileSize)
          return retval.fileURL
        .catch (error)->
          console.warn "$ngCordovaFile cordovaFile_CACHE_P ERROR"
          console.warn error   # $$$
          return $q.reject(error)

      # use dataURL immediately, but stash to FileURL and replace when ready
      cordovaFile_USE_CACHED_P: ($target, UUID, dataURL)->
        IMAGE_SIZE = $target.attr('format') if $target
        UUID = $target.attr('UUID') if !UUID
        dataURL = $target.attr('src') if !dataURL
        throw "ERROR: cannot get format from image" if !IMAGE_SIZE
        throw "ERROR: missing dataURL" if !dataURL

        self.cordovaFile_CHECK_P(UUID, IMAGE_SIZE, dataURL)
        .catch ()->
          self.cordovaFile_CACHE_P(UUID, IMAGE_SIZE, dataURL)
        .then (fileURL)->
          # console.log "\n\n >>> $ngCordovaFile.cordovaFile_USE_CACHED_P() should be cached by now, fileURL=" + fileURL
          $target.attr('src', fileURL) if $target
          return fileURL

      cordovaFile_CHECK_DIR_P : (dirname)->
        # NOTE: the Plugin currently copies FILE_URIs to '../Library/files'
        dirname = dirname || self.PLUGIN_DIR
        return $cordovaFile.checkDir( self.PLUGIN_ROOT, dirname ).then (dirEntry)->
          # console.log "$ngCordovaFile.checkDir()"
          # console.log dirEntry # $$$
          return dirEntry


    }

    ##
    #  service init
    ##
    deviceReady.waitP()
    .then (device)->
      # self.CACHE_DIR = cordova.file.applicationStorageDirectory + 'Library/files'
      return if !device.isDevice
      self.PLUGIN_ROOT = cordova.file.applicationStorageDirectory
      self.cordovaFile_CHECK_DIR_P( self.PLUGIN_DIR ).then (dirEntry)->
          return self.CACHE_ROOT = dirEntry
      .then (dirEntry)->
        if _.isEmpty self.cacheIndex
          console.warn "@@@load imgCacheSvc.cacheIndex EMPTY, check fs with cordovaFile_LOAD_CACHED_P"
          self.cordovaFile_LOAD_CACHED_P()
        else
          self.filterStashed( self.PLUGIN_ROOT )
          # console.log "\n @@@load imgCacheSvc.cacheIndex from $localStorage"
      .catch (error)->
        console.warn "$ngCordovaFile.checkDir() error, file=" + self.PLUGIN_DIR
        console.warn error # $$$

    return self
]