'use strict'

###*
 # @ngdoc overview
 # @name ionBlankApp
 # @description
 # # ionBlankApp
 #
 # Main module of the application.
###
angular
.module('ionBlankApp', [
  'ionic',
  'ngCordova',
  'onTheGo.backend',
  'onTheGo.snappiAssetsPicker'
  'ionic.contrib.ui.cards',
])
.constant('version', '0.0.1')
.run [
  '$rootScope', '$state', '$stateParams', '$ionicPlatform', 'PARSE_CREDENTIALS'
  ($rootScope, $state, $stateParams, $ionicPlatform, PARSE_CREDENTIALS)->
    $ionicPlatform.ready ()->
      # Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
      # for form inputs)
      cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true) if window.cordova?.plugins.Keyboard
      # org.apache.cordova.statusbar required
      StatusBar.styleDefault() if window.StatusBar?

    Parse.initialize( PARSE_CREDENTIALS.APP_ID, PARSE_CREDENTIALS.JS_KEY )
    $rootScope.sessionUser = Parse.User.current()

    # deprecate?
    $rootScope.$state = $state;
    $rootScope.$stateParams = $stateParams;  

    _alreadyLogged = {}
    window._logOnce = (id, message)->
      return if _alreadyLogged[id]
      message = JSON.stringify message if !_.isString message
      console.log ["\n\n _logOnce:", message, " \n\n"].join(' &&& ')
      return _alreadyLogged[id] = message
]
.factory 'SideMenuSwitcher', ['$window',
($window)->

  self = {
    isEmpty: (side)->
      # use for ion-side-menu attr:is-enabled and also ng-show <ion-nav-buttons side=""> 
      return _.isEmpty self.leftSide.src if side=='left'
      return _.isEmpty self.rightSide.src if side=='right' 
      return true

    setSrc: (side, src)->
      self.leftSide.src = src if side='left'
      self.rightSide.src = src if side='right'
      # add additional code here
      return

    leftSide:
      src: ''
    rightSide: 
      src: ''

    mediaQuery : (mq='(min-width:768px)')->
      return $window.matchMedia(mq).matches


    watch: {
      workorder: null
    } 
  }
  return self
]
.config ($stateProvider, $urlRouterProvider)->
  $stateProvider
    .state('app', {
      url: "/app",
      # name: 'app',
      abstract: true,
      views:
        'appContent':
          templateUrl: "views/menu.html",
          controller: 'AppCtrl'
        'appPartials':
          templateUrl: "views/template/app-partials.html"
        'workorderPartials':
          templateUrl: "views/workorders/workorder-partials.html"
    })


    # directive:gallery
    # view:top-picks
    # view:camera-roll
    .state('app.top-picks', {
      url: "/top-picks",
      views: {
        'menuContent' : {
          templateUrl: "views/top-picks.html"
          controller: 'TopPicksCtrl'
        }
      }
    })
    .state('app.top-picks.favorites', {
      url: "/favorites",
    })
    .state('app.top-picks.shared', {
      url: "/shared",
    })    


    .state('app.choose', {
      url: "/choose",
      abstract: true,
      views: {
        'menuContent' : {
          templateUrl: "views/choose.html"
          controller: 'ChooseCtrl'
        }
      }
    })
    .state('app.choose.calendar', {
      url: "/calendar",
      views: {
        'chooseCalendar' : {
          templateUrl: "views/choose-calendar.html"
          # controller: 'ChooseCtrl'
        }
      }
    })
    .state('app.choose.camera-roll', {
      url: "/camera-roll",
      # url: "",    # default 'state'
      views: {
        'chooseCameraRoll' : {
          templateUrl: "views/choose-camera-roll.html"
        }
      }
    })




    .state('app.checkout', {
      url: "/checkout",
      abstract: true
      views: {
        'menuContent' : {
          templateUrl: "views/checkout.html"
          controller: 'CheckoutCtrl'
        }
      }
    })
    .state('app.checkout.order-detail', {
      url: "/order-detail/:from",
      views: {
        'checkoutContent' : {
          templateUrl: "views/checkout-order-detail.html"
        }
      }
    })
    .state('app.checkout.payment', {
      url: "/payment",
      views: {
        'checkoutContent' : {
          templateUrl: "partials/checkout/payment"
        }
      }
    })
    .state('app.checkout.sign-up', {
      url: "/sign-up",
      views: {
        'checkoutContent' : {
          templateUrl: "views/checkout-user.html"
        }
      }
    })
    .state('app.checkout.terms-of-service', {
      url: "/terms-of-service",
      views: {
        'checkoutContent' : {
          templateUrl: "views/checkout-user.html"
        }
      }
    })
    .state('app.checkout.submit', {
      url: "/submit",
      views: {
        'checkoutContent' : {
          templateUrl: "partials/checkout/submit"
        }
      }
    })
    .state('app.checkout.complete', {
      url: "/complete",
      views: {
        'checkoutContent' : {
          templateUrl: "partials/checkout/complete"
        }
      }
    })

    .state('app.orders', {
      url: "/orders",
      views: {
        'menuContent' : {
          templateUrl: "views/orders.html"
          controller: 'OrdersCtrl'
        }
      }
    })
    .state('app.orders.detail', {
      url: "/:oid",
      views: {
        'menuContent' : {
          templateUrl: "views/orders.html"
          controller: 'OrdersCtrl'
        }
      }
    })

    .state('app.uploader', {
      url: "/uploader",
      views: {
        'menuContent' : {
          templateUrl: "views/upload.html"
          controller: 'UploadCtrl'
        }
      }
    })


    .state('app.settings', {
      url: "/settings",
      abstract: true
      views: {
        'menuContent' : {
          template: '<ion-view title="Settngs" hide-back-button="true" ><ion-nav-view name="settingsContent" animation="slide-left-right"></ion-nav-view></ion-view>'
          controller: 'SettingsCtrl'
        }
      }
    })
    .state('app.settings.main', {
      url: "",
      views: {
        'settingsContent' : {
          templateUrl: "views/settings.html"
          controller: 'SettingsCtrl'
        }
      }
    })
    .state('app.settings.profile', {
      url: "/profile",
      views: {
        'settingsContent' : {
          templateUrl: "views/settings-profile.html"
          controller: 'SettingsCtrl'
        }
      }
    })
    .state('app.settings.sign-in', {
      url: "/sign-in",
      views: {
        'settingsContent' : {
          # templateUrl: "partials/signin"
          templateUrl: "views/template/sign-in.html"
          controller: 'SettingsCtrl'
        }
      }
    })
    .state('app.settings.terms-of-service', {
      url: "/terms-of-service",
      views: {
        'settingsContent' : {
          templateUrl: "views/settings-tos.html"
          controller: 'SettingsCtrl'
        }
      }
    })


    .state('app.help', {
      url: "/help",
      abstract: true
      views:
        'menuContent':
          template: '<ion-view title="Help" hide-back-button="true" ><ion-nav-view  id="help" name="helpContent" animation="slide-left-right"></ion-nav-view></ion-view>'
          controller: 'HelpCtrl'
    })
    .state('app.help.main', {
      url: "",
      views: {
        'helpContent' : {
          templateUrl: "views/help.html"
        }
      }
    })
    .state('app.help.welcome', {
      url: "/welcome",
      views: {
        'helpContent' : {
          templateUrl: "help/welcome"
        }
      }
    })
    .state('app.help.pricing', {
      url: "/pricing",
      views: {
        'helpContent' : {
          templateUrl: "help/pricing"
        }
      }
    })
    .state('app.help.about', {
      url: "/about",
      views: {
        'helpContent' : {
          templateUrl: "help/about"
        }
      }
    })
    #
    # Workorder Management System
    #
    .state('app.workorders', {
      url: "/workorders",
      views: {
        'menuContent': {
          template: '<ion-view title="Workorders" hide-back-button="true" ><ion-nav-view  id="workorder" name="workorderContent" animation="slide-left-right"></ion-nav-view></ion-view>'
        }
        'workorderPartials':
          templateUrl: "views/workorders/workorder-partials.html"  
      }
    })
    .state('app.workorders.all', {
      url: "/all",
      views: {
        'workorderContent' : {
          templateUrl: "views/workorders/workorders.html"
          controller: 'WorkordersCtrl'
        }
      }
    })
    .state('app.workorders.detail', {
      url: "/:woid",
      views: {
        'workorderContent' : {
          templateUrl: "views/workorders/workorders.html"
          controller: 'WorkordersCtrl'
        }
      }
    })
    .state('app.workorders.photos', {
      url: "/:woid/photos",
      views: {
        'workorderContent' : {
          templateUrl: "views/workorders/workorder-photos.html"
          controller: 'WorkorderPhotosCtrl'
        }
      }
    })
    .state('app.workorders.photos.todo', {
      url: "/todo",
    })
    .state('app.workorders.photos.picks', {
      url: "/picks",
    })    
  # if none of the above states are matched, use this as the fallback
  $urlRouterProvider.otherwise('/app/top-picks');  
  # $urlRouterProvider.otherwise('/app/settings');  

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
      byteString = atob(dataURI.split(',')[1])

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


    _.extend ImgCache.options, _IMAGE_CACHE_defaults

    deviceReady.waitP().then ()->
      ImgCache.init()



    self = {
      cacheIndex : {} # index of cached files by UUID
      mostRecent : [] # stack for garbage collection, mostRecently used UUID on the 'top'
      CACHE_DIR : '/'  # ./Library/files/  it seems $cordovaFile requires this as root
      cacheRoot : null
      isDataURL : (src)->
        throw "isDataURL() ERROR: expecting string" if typeof src != 'string'
        return /^data:image/.test( src )

      getExt: (dataURL)->
        return if !self.isDataURL(dataURL)
        mimeType = dataURL[10..20]
        return 'jpg' if /jpg|jpeg/i.test(mimeType)
        return 'png' if /png/i.test(mimeType)
        return 

      XXXwaitP: ()->
        return _promise if _promise
        deferred = $q.defer()
        _cancel = $timeout ()->
            return deferred.reject("ERROR: ImgCache.init TIMEOUT")
          , _timeout
          ImgCache.init ()->
              return deferred.resolve("ImgCache.init() ready!")
            , (error)->
              return deferred.reject("ERROR: ImgCache.init TIMEOUT")
        return _promise = deferred.promise


      getFilename: (UUID, size, dataURL)->
        ext = self.getExt(dataURL)
        return false if !ext || !UUID
        return filePath = UUID[0...36] + '-' + size + '.' + ext

      isStashed:  (UUID, size)->
        # NOTE: we don't know the extention when we check isStashed
        hashKey = [ UUID[0...36] ,size].join(':') 
        src = self.cacheIndex[hashKey]?.fileURL || false
        if src
          console.log "\n\n >>> STASH HIT !!!  file=" + src 
          self.mostRecent.unshift(hashKey)
          self.mostRecent = _.unique(self.mostRecent)
        return src

      isStashed_P:  (UUID, size, dataURL)->
        # NOTE: we don't know the extention when we check isStashed, so guess 'jpg'
        dataURL = "data:image/jpg;base64," if !dataURL
        return self.cordovaFile_CHECK_P(UUID, size, dataURL)

      stashFile: (UUID, size, fileURL, fileSize)->
        hashKey = [ UUID[0...36] ,size].join(':') 
        console.log "\n\n >>> STASH file=" + hashKey + ", url=" + fileURL
        self.cacheIndex[hashKey] = {
          fileURL: fileURL
          fileSize: fileSize
        }

      stashSize: ()->
        total = _.reduce self.cacheIndex, (total, o)->
            return total += o.fileSize
          , 0
        return total

      unstashFile: (UUID, size)->
        hashKey = if size then hashKey = [ UUID[0...36] ,size].join(':') else UUID
        "delete from locaslStorage, then remove from stash"
        "make sure you check UUID && UUID[0...36]"
        "???: how do we delete from cameraRoll.dataURLs without a circular reference???"
        "NOTE: image.src may need to detect a missing cache URL"

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

              parts = file.name.split('-')
              tail = parts.pop()
              size = 'preview' if tail.indexOf('preview') == 0
              size = 'thumbnail' if tail.indexOf('thumbnail') == 0
              console.error "ERROR: cannot parse size from fileURL, name=" + file.name if !size
              UUID = parts.join('-')

              fileURL = file.nativeURL || file.toURL()
              promises.push self.getMetaData_P(file).then (meta)->
                fileSize = meta.size
                self.stashFile UUID, size, fileURL, fileSize
                return fileSize

              filenames.push file.name
              return
            console.log "\n\n *** cordovaFile_LOAD_CACHED_P cached. file count=" + filenames.length
            console.log filenames # $$$  
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
        blob = _dataURItoBlob(dataURL)

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
            console.log retval # $$$
            return retval
        .catch (error)->
            console.log "$ngCordovaFile writeFile ERROR"
            console.log error
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
          console.log retval # $$$
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
.controller 'AppCtrl', [
  '$scope', '$rootScope', '$ionicModal', '$timeout', '$q', '$ionicPlatform', 
  'SideMenuSwitcher', '$ionicSideMenuDelegate'
  'otgData', 'otgParse', 'otgWorkorder', 'otgWorkorderSync', 'otgUploader'
  'snappiMessengerPluginService', 
  'deviceReady', 'cameraRoll', 'appConsole'
  'TEST_DATA', 'imageCacheSvc'
  ($scope, $rootScope, $ionicModal, $timeout, $q, $ionicPlatform, SideMenuSwitcher, $ionicSideMenuDelegate, 
    otgData, otgParse, otgWorkorder, otgWorkorderSync, otgUploader
    snappiMessengerPluginService, 
    deviceReady, cameraRoll, appConsole,
    TEST_DATA, imageCacheSvc  )->

    # dynamically update left side menu
    $scope.SideMenuSwitcher = SideMenuSwitcher  
    SideMenuSwitcher.leftSide.src = 'partials/left-side-menu'

    # // Form data for the login modal
    $scope.loginData = {};

    # // Create the login modal that we will use later
    $ionicModal.fromTemplateUrl('templates/login.html', {
      scope: $scope
    }).then((modal)-> 
      $scope.modal = modal;
    );

    # // Triggered in the login modal to close it
    $scope.closeLogin = ()->
      $scope.modal.hide();

    # // Open the login modal
    $scope.login = ()->
      $scope.modal.show();

    # // Perform the login action when the user submits the login form
    $scope.doLogin = ()->
      console.log('Doing login', $scope.loginData);

      # // Simulate a login delay. Remove this and replace with your login
      # // code if using a login system
      $timeout(()->
          $scope.closeLogin();
        , 1000);

    $scope.toggleHelp = ()->
      $scope.config.help = !$scope.config.help  
      console.log "help="+ if $scope.config.help then 'ON' else 'OFF'


    $scope.menu = {
      top_picks: 
        count: 0
      orders:
        count: 0
      archived:
        count: 0
      uploader:
        count: 0
    }

    # config values read from localstorage, set in settings
    $scope.config = {
      'no-view-headers' : true
      help: false
      privacy:
        'only-mothers': false
      upload:
        'auto-upload': false
        'use-cellular-data': false
        'use-720p-service': true
        'rate-control': 80
      archive:
        'copy-top-picks': false
        'copy-favorites': true  
      sharing:  
        'use-720p-sharing': false
      'dont-show-again':
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

    }

    $rootScope.deviceId = "1234567890" # updated after deviceReady.waitP()
    $rootScope.user = $scope.XXXuser = {
      id: null

      username: null
      password: null
      email: null
      emailVerified: false

      # username: 'bob'
      # password: 'required'
      # email: 'this@that'
      # emailVerified: true

      tos: true
      rememberMe: false
      isRegistered: false 
    } 
    otgParse.mergeSessionUser()



    $scope.$watch 'config', (newVal, oldVal)->
        return _prefs.store newVal, oldVal
      , true

    # initial app preferences, priority to NSUserDefaults via plugin
    _prefs = {
      store: (newVal, oldVal)->
        if plugins?.appPreferences?
          prefs = plugins.appPreferences
          ok = (value)-> # appPreferences.store returns "OK"
            console.log "NSUserDefaults save: value=" + value
            # prefs.fetch okAlert, fail, 'prefs'
            return

          okAlert = (value)->
            console.log "NSUserDefaults fetch SUCCESS: value=" + JSON.stringify value
            return  

          fail = (err)->
            console.warn "NSUserDefaults: error=" + JSON.stringify err
            return

          return prefs.store ok, fail, 'prefs', newVal
        else 
          # save to localStorage
          return
      load: ()->
        promise = $q.defer()
        if plugins?.appPreferences
          # use appPrefereces
          plugins.appPreferences.fetch (value)->
              if _.isEmpty(value)
                cfg = {status:"EMPTY"}
              else  
                cfg = JSON.parse(value) 
              return promise.resolve(cfg)   

            , (err)->
              console.warn "AppPreferences load() FAIL: error=" + JSON.stringify err
              return promise.resolve($scope.config) 
            , 'prefs'
        else 
          promise.resolve({status:"PLUGIN unavailable"}) 

        return promise.promise
    }

    $scope.loadMomentsFromCameraRollP = ()->  # on button click

      IMAGE_FORMAT = 'thumbnail'    # [thmbnail, preview, previewHD]
      # TEST_LIMIT = 5 # snappiMessengerPluginService.MAX_PHOTOS
      start = new Date().getTime()

      return cameraRoll.loadCameraRollP( {size: IMAGE_FORMAT} ) 


    # Dev/Debug tools
    _LOAD_DEBUG_TOOLS = ()->
      # currently testing
      $scope.MessengerPlugin = snappiMessengerPluginService
      $rootScope.appConsole = appConsole


    _LOAD_BROWSER_TOOLS = ()->
      # moment and photos loaded in cameraRoll service via deviceReady.waitP()
      # add some test data for favorite and shared
      TEST_DATA.addSomeTopPicks( cameraRoll.photos)
      TEST_DATA.addSomeFavorites( cameraRoll.photos)
      TEST_DATA.addSomeShared( cameraRoll.photos)
      # add item.height for collection-repeat

      _.each cameraRoll.photos, (e,i,l)->
        e.originalHeight = if /^[EF]/.test(e.UUID) then 400 else 240
        e.originalWidth = 320
        e.dateTaken = e.date
        e.src = TEST_DATA.lorempixel.getSrc(e.UUID, e.originalWidth, e.originalHeight, TEST_DATA)
        return

      return


    init = ()->
      _LOAD_DEBUG_TOOLS()

      $scope.loadMomentsFromCameraRollP().finally ()->
        console.log "\n\n*** cameraRoll mapped\n"
        otgWorkorderSync.SYNC_ORDERS($scope, 'owner', 'force') if !$rootScope.$state.includes('app.workorders')


      deviceReady.waitP().then ()->
        $scope.config['no-view-headers'] = deviceReady.isWebView() && false
        $rootScope.deviceId = deviceReady.deviceId()

        if !deviceReady.isWebView()
          _LOAD_BROWSER_TOOLS() 
          $scope.orders = TEST_DATA.orders 
        
        _prefs.load().then (config)->
          if config?.status == "PLUGIN unavailable"
            console.warn "AppPreferences" + config.status
          else if config?.status == "EMPTY"
            console.log "NSUserDefaults=" + JSON.stringify config
            _prefs.store $scope.config
          else 
            console.log "NSUserDefaults=" + JSON.stringify config
            _.extend $scope.config, config
          return

        return  # end $ionicPlatform.ready

    init()

    window.debug = _.extend window.debug || {} , {
      user: $scope.user
      cameraRoll: cameraRoll
      workorders: otgWorkorderSync._workorderColl
      imgCache: imageCacheSvc
    }

  ]