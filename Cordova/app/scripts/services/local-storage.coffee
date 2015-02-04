'use strict'

###*
 # @ngdoc factory
 # @name onTheGo.localStorage
 # @description 
 # methods for local storage, including caching DataURLs and remote img URLs
 # 
###


angular
.module 'onTheGo.localStorage', []

.factory 'imageCacheSvc', [
  '$q', '$timeout',  'deviceReady', '$cordovaFile'
  ($q, $timeout, deviceReady, $cordovaFile)->
    _promise = null
    _timeout = 2000
    _IMAGE_CACHE_defaults = {
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
      catch error
        console.log('ERROR: Blob support not available for dataURItoBlob')
      return false


    # _.extend ImgCache.options, _IMAGE_CACHE_defaults

    # deviceReady.waitP().then ()->
    #   ImgCache.init()

    _bytesToSize = (bytes)-> 
       return '0 Byte' if (bytes == 0) 
       k = 1000;
       sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
       i = Math.floor(Math.log(bytes) / Math.log(k));
       return (bytes / Math.pow(k, i)).toPrecision(3) + ' ' + sizes[i];


    self = {
      cacheIndex : {} # index of cached files by UUID
      mostRecent : [] # stack for garbage collection, mostRecently used UUID on the 'top'
      CACHE_DIR : '/'  # ./Library/files/  it seems $cordovaFile requires this as root
      cacheRoot : null
      LIMITS:
        MAX_PREVIEW: 500
        MOST_RECENT: 1000 # apply _.unique on reaching limit
      isDataURL : (src)->
        throw "isDataURL() ERROR: expecting string" if typeof src != 'string'
        return /^data:image/.test( src )

      getExt: (dataURL)->
        return if !self.isDataURL(dataURL)
        mimeType = dataURL[10..20]
        return 'jpg' if /jpg|jpeg/i.test(mimeType)
        return 'png' if /png/i.test(mimeType)
        return 

      getFilename: (UUID, size, dataURL)->
        ext = self.getExt(dataURL)
        return false if !ext || !UUID
        return filePath = UUID[0...36] + '-' + size + '.' + ext

      # NOTE: this 'fast' version called by camera.getDataURL
      # if not stashed, the UUID will be queued with cameraRoll.queueDataURL()
      isStashed:  (UUID, size)-> 
        # NOTE: we don't know the extension when we check isStashed
        hashKey = [ UUID[0...36] ,size].join(':') 
        src = self.cacheIndex[hashKey]?.fileURL || false
        if src
          # console.log "\n\n >>> STASH HIT !!!  file=" + src.slice(-60) 
          self.mostRecent.unshift(hashKey)
          if self.mostRecent.length >  self.LIMITS.MOST_RECENT
            self.mostRecent = _.unique(self.mostRecent) 
            self.clearStashedP('preview', self.LIMITS.MAX_PREVIEW)
        return src

      isStashed_P:  (UUID, size, dataURL)->
        # NOTE: we don't know the extention when we check isStashed, so guess 'jpg'
        dataURL = "data:image/jpg;base64," if !dataURL
        return self.cordovaFile_CHECK_P(UUID, size, dataURL)

      stashFile: (UUID, size, fileURL, fileSize)->
        hashKey = [ UUID[0...36] ,size].join(':') 
        # console.log "\n\n >>> STASH file=" + hashKey + ", url=" + fileURL
        self.cacheIndex[hashKey] = {
          fileURL: fileURL
          fileSize: fileSize
        }

      stashSize: ()->
        total = _.reduce self.cacheIndex, (total, o)->
            return total += o.fileSize
          , 0
        return total

      stashStats: ()->
        return {
          size: _bytesToSize( self.stashSize() )
          count: _.values( self.cacheIndex ).length
        }

      unstashFileP: (UUID, size)->
        hashKey = if size then hashKey = [ UUID[0...36] ,size].join(':') else UUID
        o = self.cacheIndex[hashKey]
        return $q.reject("stashFile not found") if !o
        filename = self.CACHE_DIR + o.fileURL.split('/').pop()
        return $cordovaFile.removeFile(filename).then (retval)->
          console.log "\n %%% $cordovaFile.removeFile complete, filename=" + filename.slice(-60)
          console.log retval # $$$
          delete self.cacheIndex[ hashKey ]
          return
        

      ## @param type string, [preview|thumbnail], keep = count 
      clearStashedP: (type, keep)->
        $timeout ()->
            console.log "\n\n *** clearStashedP() begin, size="+self.stashSize()
            promises = []

            if keep && type
              keyOfType = _.filter self.mostRecent, (hashKey)->
                return hashKey.indexOf(type) > -1
              hashKeys = keyOfType.slice keep
            else if keep
              hashKeys = self.mostRecent.slice keep
            else 
              hashKeys = _.keys self.cacheIndex

            _.each hashKeys, (hashKey)->
              return if type && hashKey.indexOf(type) == -1
              promises.push self.unstashFileP(hashKey)
            return $q.all(promises).then ()->
              self.mostRecent = self.mostRecent.slice(0,keep) if keep
              console.log "*** clearStashedP() END, size="+self.stashSize()
          , 100

      getCacheKeyFromFilename: (filename)->
        parts = filename.split('-')
        tail = parts.pop()
        size = 'preview' if tail.indexOf('preview') == 0
        size = 'thumbnail' if tail.indexOf('thumbnail') == 0
        console.error "WARNING: cannot parse size from fileURL, name=" + filename if !size
        UUID = parts.join('-')
        return [UUID] if !size
        return [UUID, size]


      cordovaFile_LOAD_CACHED_P : (dirEntry)->
        # cordova.file.cacheDirectory : ./Library/Caches
        # cordova.file.documentsDirectory : ./Library/Documents

        dirEntry = self.cacheRoot if !dirEntry

        dfd = $q.defer()
        fsReader = dirEntry.createReader()
        fsReader.readEntries (entries)->
            filenames = []
            promises = []
            _.each entries, (file)->
              return if !file.isFile

              [UUID, size] = self.getCacheKeyFromFilename(file.name)

              fileURL = file.nativeURL || file.toURL()
              promises.push self.getMetaData_P(file).then (meta)->
                fileSize = meta.size
                self.stashFile UUID, size, fileURL, fileSize
                return fileSize

              filenames.push file.name
              return
            console.log "\n\n *** cordovaFile_LOAD_CACHED_P cached. file count=" + filenames.length
            # console.log filenames # $$$  
            return $q.all(promises).then (sizes)->
              return dfd.resolve(filenames)
          , (error)->
            console.log error # $$$
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
        filePath = self.isStashed UUID, size
        return $q.when (filePath) if filePath


        filePath = self.getFilename(UUID, size, dataURL)
        return $q.reject('ERROR: unable to get valid Filename') if !filePath

        # filePath = result['target']['localURL']
        console.log "\n\n >>> $ngCordovaFile.checkFile() for file=" + filePath
        return $cordovaFile.checkFile( self.CACHE_DIR + filePath )
        .catch (error)->
          # console.log error # $$$
          console.log "$ngCordovaFile.checkFile() says DOES NOT EXIST, file=" + filePath + "\n\n"
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
          console.log error # $$$
          console.log "$ngCordovaFile.checkFile() some OTHER error, file=" + filePath + "\n\n"
          return $q.reject(error)


      cordovaFile_WRITE_P: (UUID, size, dataURL)->
        filePath = self.getFilename(UUID, size, dataURL)
        return $q.reject('ERROR: unable to get valid Filename') if !filePath
        
        try
          blob = _dataURItoBlob(dataURL)
        catch error
          console.warn "error: cordovaFile_WRITE_P="+ dataURL[0...100]
          console.warn error

        console.log "\n >>> $ngCordovaFile.writeFile() for file=" + filePath
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
            console.log "$ngCordovaFile writeFile ERROR"
            console.log error # $$$
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
          console.log "$ngCordovaFile cordovaFile_CACHE_P ERROR"
          console.log error   # $$$
          return $q.reject(error)

      cordovaFile_USE_CACHED_P: ($target, UUID, dataURL)->
        IMAGE_SIZE = $target.attr('format') if $target
        UUID = $target.attr('UUID') if !UUID
        dataURL = $target.attr('src') if !dataURL
        throw "ERROR: cannot get format from image" if !IMAGE_SIZE

        self.cordovaFile_CHECK_P(UUID, IMAGE_SIZE, dataURL)
        .catch ()->
          self.cordovaFile_CACHE_P(UUID, IMAGE_SIZE, dataURL)
        .then (fileURL)->
          console.log "\n\n >>> $ngCordovaFile.cordovaFile_USE_CACHED_P() should be cached by now, fileURL=" + fileURL
          $target.attr('src', fileURL) if $target
          return fileURL


    }
    deviceReady.waitP()
    .then ()->
      # self.CACHE_DIR = cordova.file.cacheDirectory if cordova?.file
      # self.CACHE_DIR = cordova.file.documentsDirectory if cordova?.file
      self.CACHE_DIR = '/' # ./Library/files/  it seems $cordovaFile requires this as root
      $cordovaFile.checkDir( self.CACHE_DIR ).then (dirEntry)->
          console.log "$ngCordovaFile.checkDir()"
          console.log dirEntry # $$$
          return self.cacheRoot = dirEntry
      .then (dirEntry)->
        self.cordovaFile_LOAD_CACHED_P()
      .catch (error)->
          console.log error # $$$
          console.log "$ngCordovaFile.checkDir() error, file=" + self.CACHE_DIR + "\n\n"
      # .then ()->
      #   return $cordovaFile.createDir( 'CACHE_DIR' )
      # .then (dirEntry)->
      #     console.log "$ngCordovaFile.createDir()"
      #     console.log dirEntry # $$$
      #     self.fs_CACHE_DIR = dirEntry
      # .catch (error)->
      #     console.log error # $$$
      #     console.log "$ngCordovaFile.createDir() error, file=" + self.CACHE_DIR + "\n\n"


    return self
]