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
    .state('nav-menu', {
      url: "/nav-menu",
      views:
        'appContent':
          templateUrl: "views/menu-only.html",
          controller: 'AppCtrl'
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

.factory 'imageCacheSvc', [
  '$q', '$timeout',  'deviceReady'
  ($q, $timeout, deviceReady)->
    _promise = null
    _timeout = 2000
    _defaults = {
      chromeQuota: 50*1024*1024
      debug: true
      skipURIencoding: true    # required for dataURLs
      usePersistentCache: true
    }
    _.extend ImgCache.options, _defaults

    deviceReady.waitP().then ()->
      ImgCache.init()

    self = {
      cacheIndex : {} # index of cached files by UUID
      mostRecent : [] # stack for garbage collection, mostRecently used UUID on the 'top'
      cacheTemplate: 'imgcache/{uuid}.jpg'
      isDataURL : (src)->
        return /^data:image/.test src[10..20]
      waitP: ()->
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

      cacheDataURLP: ($targetOrDataURL, UUID, useCached=true)->
        hashkey = self.getHashKey($targetOrDataURL) 
        UUID = hashkey if hashkey
        UUID = UUID[0...36] # localStorage might balk at '/' in pathname
        isTarget = $targetOrDataURL.src? || $targetOrDataURL.attr?
        if isTarget
          $target = $targetOrDataURL
          dataURL = $targetOrDataURL.attr('src') 
        else 
          dataURL = $targetOrDataURL


        return $q.reject "ERROR: dataURL is missing!" if !dataURL && !UUID

        return self.waitP().then ()->
            return self.useCachedFileP($target) if useCached
            return $q.reject()
          .then (found)->
            return $q.reject() if !found
            console.log "\n\nCACHE HIT!!!!\n\n"
            # return self.useCachedFileP( $target, UUID) 
            
          .catch ()->
            deferred = $q.defer()
            return $q.reject('dataURL is missing: load from MessengerPlugin?') if !dataURL

            ImgCache.cacheDataURL dataURL
              , UUID
              , (filepath, fileEntry)-> 
                
                if !filepath
                  ImgCache.useCachedFile($target)
                  return deferred.resolve("success") 

                console.log "\n *** right here 2 filepath=" + filepath
                console.log "ImgCache.cacheDataURL(): UUID="+UUID+", fileEntry=" + fileEntry?.toURL()
                self.cacheIndex[UUID] = filepath.slice(1) # fileEntry.toURL()

                console.log self.cacheIndex  # $$$

                return deferred.resolve("success")
              , (error)->
                console.log "\n *** right here 3"
                console.log error
                return deferred.reject("ImgCache.cacheFile() errors. see log")
            return deferred.promise.then ()->
                if $target && useCached
                  return self.useCachedFileP($target, UUID)
              , (error)->
                console.log error
          .catch (error)->
            console.log error
            return $q.reject(error)

      getHashKey: ($targetOrUUID)->
        # priority: $target.attr('uuid') > UUID > $target.attr(src)
        $targetOrUUID = angular.element($targetOrUUID) if $targetOrUUID instanceof HTMLElement
        UUID = $targetOrUUID.attr('uuid') if $targetOrUUID.attr
        UUID = $targetOrUUID if !UUID && _.isString $targetOrUUID
        UUID = UUID[0...36] if UUID
        return UUID if UUID
        # degrade to img.src for imageCacheSvc
        src = $targetOrUUID.attr('src')
        return src if src

        throw "ERROR: cannot find Hashkey for imageCacheSvc!!!"



      useCachedFileP: ($target)->
        UUID = self.getHashKey($target) 
        UUID = UUID[0...36] if UUID
        return self.waitP().then ()->
          deferred = $q.defer()
          # filepath = self.cacheIndex[UUID]
          # filepath =  self.cacheTemplate.replace('{uuid}', UUID) if !filepath
          ImgCache.useCachedDataURL $target 
            , ()->
              self.mostRecent.splice self.mostRecent.indexOf(UUID), 1
              self.mostRecent.push(UUID)
              return deferred.resolve("success")
            , ($img)->
              # console.log "useCachedFileP, file not found in cache"
              return deferred.reject("ImgCache.useCachedFileP, file not found")
          return deferred.promise

      isCachedP: ($targetOrUUID)->
        hashkey = self.getHashKey($targetOrUUID)

        return self.waitP().then ()->
          deferred = $q.defer()
          filepath = self.cacheIndex[hashkey]
          filepath =  self.cacheTemplate.replace('{uuid}', hashkey) if !filepath
          console.log "\n\n *** checking cache for file=" + filepath
          # return deferred.resolve(!!filepath)

          ImgCache.isDataURLCached filepath, (src, isCached)->
            console.log "ImgCache isCached() says isCached=" + !!isCached + " for src=" + src
            return deferred.reject false if !isCached
            self.cacheIndex[hashkey] = src # cache in localStorage
            return deferred.resolve isCached
          return deferred.promise
      raw: (target)->
        target = angular.element(target)
        return ImgCache.cacheFile target.attr('src'), ()->
          return ImgCache.useCachedFile target, ()->
              console.log('now using local copy');
            , ()->
              console.log('could not load from cache');



    }
    return self
]
.controller 'AppCtrl', [
  '$scope', '$rootScope', '$ionicModal', '$timeout', '$q', '$ionicPlatform', 
  'SideMenuSwitcher', '$ionicSideMenuDelegate'
  'otgData', 'otgWorkorder', 
  'snappiMessengerPluginService', 
  'deviceReady', 'cameraRoll', 'appConsole'
  'TEST_DATA', 'imageCacheSvc'
  ($scope, $rootScope, $ionicModal, $timeout, $q, $ionicPlatform, SideMenuSwitcher, $ionicSideMenuDelegate, otgData, otgWorkorder, 
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
        count: '?'   # get cached value from localstorage
      archived:
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
    $rootScope.user = $scope.user = {
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
    } 
    # get GUID
    $rootScope.deviceId = "1234567890" # updated after deviceReady.waitP()

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

    # start refresh listener for dataURL 
    $rootScope.$on 'cameraRoll.queuedDataURL', ()->
      snappiMessengerPluginService.fetchDataURLsFromQueue()

    $scope.loadMomentsFromCameraRollP = ()->  # on button click

      IMAGE_FORMAT = 'thumbnail'    # [thmbnail, preview, previewHD]
      TEST_LIMIT = 5 # snappiMessengerPluginService.MAX_PHOTOS
      start = new Date().getTime()


      return snappiMessengerPluginService.mapAssetsLibraryP().then (mapped)->
          ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
          end = new Date().getTime()
          moments = cameraRoll.loadMomentsFromCameraRoll( mapped ) # mapped -> moments

          # returns: {2014-07-14:[{dateTaken: UUID: }, ]}
          retval = {
            title: "*** snappiMessengerPluginService.mapAssetsLibraryP() ***"
            elapsed : (end-start)/1000
            'moment[0].value' : cameraRoll.moments[0].value
            'mapped[0..10]': mapped[0..10]
          }
          # appConsole.show( retval )
          return mapped
        , (error)->
          console.log error
          # appConsole.show( error)
          return $q.reject(error)
      .then (mapped)->
        # preload thumbnail DataURLs for cameraRoll moment previews
        momentPreviewAssets = cameraRoll.getMomentPreviewAssets() # do this async
        console.log "\n\n\n*** preloading moment thumbnails for UUIDs: " + JSON.stringify momentPreviewAssets
        return snappiMessengerPluginService.getDataURLForAssetsByChunks_P( 
          momentPreviewAssets
          , IMAGE_FORMAT                          
          , snappiMessengerPluginService.SERIES_DELAY_MS 
        ).then ()->
          console.log "*** preload complete "

      .then (photos)->
        return photos  # DEBUG only

        # # show results in AppConsole
        # truncated = {
        #   "desc": "cameraRoll.dataURLs"
        #   photos: cameraRoll.photos[0..TEST_LIMIT]
        #   dataURLs: {}
        # }
        # if deviceReady.isWebView()
        #   _.each cameraRoll.dataURLs[IMAGE_FORMAT], (dataURL,uuid)->
        #     truncated.dataURLs[uuid] = dataURL[0...40]
        # else 
        #   _.each photos, (v,k)->
        #     truncated.dataURLs[v.UUID] = v.data[0...40]
        
        # # console.log truncated # $$$
        # $scope.appConsole.show( truncated )
        # return photos


    

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

      # otgWorkorder methods need access to library of moments
      'skip' || otgWorkorder.setMoments(cameraRoll.moments)



      # imageCacheSvc.cacheDataURLP()
      return


    $scope.orders = [] # order history

    init = ()->
      _LOAD_DEBUG_TOOLS()
      
      $scope.loadMomentsFromCameraRollP()

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
      orders: $scope.orders
      cameraRoll: cameraRoll
    }

  ]