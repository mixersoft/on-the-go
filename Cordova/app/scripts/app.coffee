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


.controller 'AppCtrl', [
  '$scope', '$rootScope', '$ionicModal', '$timeout', '$q', '$ionicPlatform', 
  'SideMenuSwitcher', '$ionicSideMenuDelegate'
  'otgData', 'otgWorkOrder',   'snappiAssetsPickerService', 'TEST_DATA',
  ($scope, $rootScope, $ionicModal, $timeout, $q, $ionicPlatform, SideMenuSwitcher, $ionicSideMenuDelegate, otgData, otgWorkOrder, snappiAssetsPickerService, TEST_DATA)->

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
      'isWebView' : true
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

      tos: false
      rememberMe: false
    } 
    # get GUID
    $rootScope.deviceId = "1234567890" # updated in otgParse.deviceReadyP()

    $scope.orders = [] # order history


    $rootScope.rightMenu = {
      isEmpty: ()->

    }

    # placeholder for cameraRoll data from mapLibraryAssets()
    $scope.cameraRoll_DATA = cameraRoll_DATA = {
      photos_ByDate : TEST_DATA.cameraRoll_byDate
      moments : null
      photos : null
    }

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

    $scope.loadCameraRollP = ()->
      return _MessengerPLUGIN.mapAssetsLibraryP().then (retval)->    # now get DataURLS...
          if retval.raw.length > _MessengerPLUGIN.MAX_PHOTOS
            console.warn "\n\nWARNING: truncating assets, max=" + _MessengerPLUGIN.MAX_PHOTOS + "\n\n"
            assets = retval.raw[0.._MessengerPLUGIN.MAX_PHOTOS]
          else assets = retval.raw
          return _MessengerPLUGIN.getDataURLForAssetsByChunks_P( assets
            , 'thumbnail'                           # [thmbnail, preview, previewHD]
            , _MessengerPLUGIN.SERIES_DELAY_MS 
          )

      .then (photos)->    
        # show results in AppConsole
        truncated = {
          "desc": "$scope.cameraRoll_DATA.dataUrls"
        }
        if "dataUrls" && true
          _.each cameraRoll_DATA.dataUrls, (v,k)->
            truncated[k] = v[0...40]
        else 
          _.each photos, (v,k)->
            truncated[v.UUID] = v.data[0...40]
        
        console.log truncated

        # $scope.appConsole.log( truncated )
        $scope.appConsole.show( truncated )
        # lookup dataUrls in cameraRoll_DATA.dataUrls 
        return cameraRoll_DATA.dataUrls


    _MessengerPLUGIN = {
      MAX_PHOTOS: 1000
      CHUNK_SIZE : 10
      SERIES_DELAY_MS: 100
      # methods for testing messenger plugin
      mapAssetsLibraryP: ()->
        console.log "mapAssetsLibrary() calling window.Messenger.mapAssetsLibrary(assets)"
        # return snappiAssetsPickerService.mapAssetsLibraryP();
        cameraRoll_DATA.dataUrls = {}
        start = new Date().getTime()
        return snappiAssetsPickerService.mapAssetsLibraryP().then (mapped)->
            ## example: [{"dateTaken":"2014-07-14T07:28:17+03:00","UUID":"E2741A73-D185-44B6-A2E6-2D55F69CD088/L0/001"}]
            end = new Date().getTime()
            photos = otgData.mapDateTakenByDays(mapped, "like TEST_DATA")
            retval = {
              elapsed : (end-start)/1000
              photos: photos
              raw: mapped
            }
            return retval
          , (error)->
            $scope.appConsole.show( JSON.stringify error)
        .then (retval)->

          _MessengerPLUGIN.replace_TEST_DATA(retval)
          $scope.appConsole.show( retval )
          return retval

      getDataURLForAssets_P: (assets, size)->
        # call getPhotosByIdP() with array
        return _MessengerPLUGIN.getPhotosByIdP( assets , size).then (photos)->
            _.each photos, (photo)->
              # merge into cameraRoll_DATA.dataUrls
              # keys:  UUID,data,elapsed
              # console.log ">>>>>>>  getPhotosByIdP(" + photo.UUID + "), DataURL[0..80]=" + photo.data[0..80]
              cameraRoll_DATA.dataUrls[ photo.UUID[0...36] ] = photo.data
              console.log "\n*****************************\n"
            # update img.src DB with dataURL  
            _MessengerPLUGIN.replace_TEST_DATA_SRC photos  
            console.log "\n********** updated src ***********\n"
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
        cameraRoll_DATA.dataUrls = {}
        promises = []
        _.each assets, (asset)->
          label = 'preview' # [preview | thumbnail]
          uuidExt = asset.UUID[0...36] + '.JPG' 
          console.log ">>>>>>>  Here in _.each, uuidExt=" + uuidExt
          promise = snappiAssetsPickerService.getAssetByIdP_snappiAssetsPicker(uuidExt, {}, null, label).then (photo)->
              console.log ">>>>>>>  getPhotosByIdP(" + photo.uuid + "), DataURL[0..20]=" + photo.data[label][0..20]
              cameraRoll_DATA.dataUrls[ photo.uuid ] = photo.data[label]
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

        TEST_DATA.cameraRoll_byDate = photos_AsTestData  
        cameraRoll_DATA.photos_ByDate = TEST_DATA.cameraRoll_byDate
        cameraRoll_DATA.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( cameraRoll_DATA.photos_ByDate ), 2
        cameraRoll_DATA.photos = otgData.parsePhotosFromMoments cameraRoll_DATA.moments
        otgWorkOrder.setMoments(cameraRoll_DATA.moments)

         # add some test data for favorite and shared
        TEST_DATA.addSomeTopPicks( cameraRoll_DATA.photos)
        TEST_DATA.addSomeFavorites( cameraRoll_DATA.photos)
        TEST_DATA.addSomeShared( cameraRoll_DATA.photos)
        _.extend window.debug , cameraRoll_DATA

      replace_TEST_DATA_SRC : (photos)->
        _.each photos, (photo, i)-> 
          UUID = photo.UUID[0...36]
          e = _.find cameraRoll_DATA.photos, {id: UUID }
          return console.log "  !!!!!!!!!!!!   replace_TEST_DATA_SRC: not found, UUID="+UUID if !e
          e.height = if photo.crop then photo.targetHeight else 240
          e.src = _MessengerPLUGIN.getDataUrlFromUUID(UUID)
          e.topPick = true          ## debug only !!!
          e.getSrc = _MessengerPLUGIN.getDataUrlFromUUID
          console.log "\n\n ##############   asset.id=" + e.id + "\ndataURL[0...20]=" + e.src[0...20]
          return


      getDataUrlFromUUID : (UUID)->
        return cameraRoll_DATA.dataUrls?[ UUID ]

      testMessengerPlugin: ()->
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

    # Dev/Debug tools
    _LOAD_DEBUG_TOOLS = ()->
      # currently testing
      $scope.MessengerPlugin = _MessengerPLUGIN
      $rootScope.getDataUrlFromUUID = _MessengerPLUGIN.getDataUrlFromUUID

      $scope.appConsole = {
        _modal: null
        message: null
        log: (message)->
          $scope.appConsole.message = message if _.isString message
          $scope.appConsole.message = JSON.stringify message, null, 2 if _.isObject message
        show: (message)->
          $scope.appConsole.log(message) if message
          $scope.appConsole._modal?.show()
        hide: ()->
          $scope.appConsole._modal?.hide()



      }
      $ionicModal.fromTemplateUrl 'partials/modal/console', {
            scope: $scope
            animation: 'slide-in-up'
          }
        .then (modal)->
            console.log "modal ready"
            $scope.appConsole._modal = modal
            $scope.$on 'destroy', ()->
              $scope.appConsole._modal.remove()
            return
          , (error)->
            console.log "Error: $ionicModal.fromTemplate"
            console.log error






    init = ()->
      _LOAD_DEBUG_TOOLS()

      $ionicPlatform.ready ()->
        $scope.config['isWebView'] = $ionicPlatform?.isWebView?()
        $scope.config['no-view-headers'] = $scope.config['isWebView'] || false

        # $timeout ()->
        #     _MessengerPLUGIN.testMessengerPlugin()
        #   , 10000
        
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

      cameraRoll_DATA.photos_ByDate = TEST_DATA.cameraRoll_byDate
      cameraRoll_DATA.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( cameraRoll_DATA.photos_ByDate ), 2
      cameraRoll_DATA.photos = otgData.parsePhotosFromMoments cameraRoll_DATA.moments

      # add some test data for favorite and shared
      TEST_DATA.addSomeTopPicks( cameraRoll_DATA.photos)
      TEST_DATA.addSomeFavorites( cameraRoll_DATA.photos)
      TEST_DATA.addSomeShared( cameraRoll_DATA.photos)
      # add item.height for collection-repeat

      _.each $scope.cameraRoll_DATA.photos, (e,i,l)->
        e.height = if e.id[-5...-4]<'4' then 400 else 240
        # e.height = 240
        # e.src = "http://lorempixel.com/"+(320)+"/"+(e.height)+"/"+lorempixelPhotos.shift()+"?"+e.id
        e.src = TEST_DATA.lorempixel.getSrc(e.id, 320, e.height, TEST_DATA)
        return

      # otgWorkOrder methods need access to library of moments
      otgWorkOrder.setMoments(cameraRoll_DATA.moments)
      $scope.orders = TEST_DATA.orders

    init()

    window.debug = _.extend window.debug || {} , {
      user: $scope.user
      moments: cameraRoll_DATA.moments
      photos: cameraRoll_DATA.photos
      orders: $scope.orders
    }

  ]