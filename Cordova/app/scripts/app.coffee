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
  'onTheGo.localStorage',
  'snappi.util',
  'ionic.contrib.ui.cards',
  'onTheGo.i18n'
  'angular-datepicker'
  'ngStorage'
  'onthego.templates'
  'snappi.notification.push'
  # 'snappi.notification.local'
  'ionic.ion.headerShrink'
])
.config ['$ionicConfigProvider', 
  ($ionicConfigProvider)->
    $ionicConfigProvider.backButton.text('Back').icon('ion-ios-arrow-back');
]
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
.config ['$stateProvider', '$urlRouterProvider', ($stateProvider, $urlRouterProvider)->
  $stateProvider
    .state('app', {
      url: "/app",
      # name: 'app',
      abstract: true,
      views:
        'appContent':
          templateUrl: "views/menu.html",
          controller: 'AppCtrl'
    })


    # directive:gallery
    # view:top-picks
    # view:camera-roll
    .state('app.top-picks', {
      url: "/top-picks",
      abstract: true
      views: {
        'menuContent' : {
          templateUrl: "views/top-picks.html"
          controller: 'TopPicksCtrl'
        }
      }
    })
    .state('app.top-picks.top-picks', {
      url: "/top-picks",
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
          templateUrl: "views/partials/checkout-payment.html"
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
          templateUrl: "views/partials/checkout-submit.html"
        }
      }
    })
    .state('app.checkout.complete', {
      url: "/complete",
      views: {
        'checkoutContent' : {
          templateUrl: "views/partials/checkout-complete.html"
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
          template: '<ion-view view-title="Settngs"><ion-nav-view name="settingsContent" animation="slide-left-right"></ion-nav-view></ion-view>'
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
    .state('app.settings.privacy', {
      url: "/privacy-policy",
      views: {
        'settingsContent' : {
          templateUrl: "views/settings-privacy.html"
          controller: 'SettingsCtrl'
        }
      }
    })
    .state('app.settings.legal', {
      url: "/legal",
      views: {
        'settingsContent' : {
          templateUrl: "views/settings-legal.html"
          controller: 'SettingsCtrl'
        }
      }
    })

    .state('app.help', {
      url: "/help",
      abstract: true
      views:
        'menuContent':
          template: '<ion-view view-title="Help" hide-back-button="true" ><ion-nav-view  id="help" name="helpContent" animation="slide-left-right"></ion-nav-view></ion-view>'
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
    .state('app.help.pricing', {
      url: "/pricing",
      views: {
        'helpContent' : {
          templateUrl: "views/partials/help-pricing.html"
        }
      }
    })
    .state('app.help.about', {
      url: "/about",
      views: {
        'helpContent' : {
          templateUrl: "views/partials/help-about.html"
        }
      }
    }) 
    .state('app.help.me', {
      url: "/me",
      views: {
        'helpContent' : {
          templateUrl: "views/partials/help-me.html"
        }
      }
    })
    # user view of orders
    .state('app.orders', {
      url: "/orders",
      abstract: true
      views: {
        'menuContent' : {
          templateUrl: "views/orders.html"
          controller: 'OrdersCtrl'
        }
      }
    })
    .state('app.orders.open', {
      url: "/open",
      views: {
        'open-tab' : {
          templateUrl: "views/partials/tab-order-open.html"
        }
      }      
    })
    .state('app.orders.complete', {
      url: "/complete",
      views: {
        'complete-tab' : {
          templateUrl: "views/partials/tab-order-complete.html"
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
    #
    # Workorder Management System
    #
    .state('app.workorders', {
      url: "/workorders",
      abstract: true
      views: {
        'menuContent': {
          templateUrl: "views/workorders/workorders.html"
          controller: 'WorkordersCtrl'
        }
      }
    })
    .state('app.workorders.open', {
      url: "/open",
      views: {
        'workorder-tab-open' : {
          templateUrl: "views/partials/workorders/tab-workorder-open.html"
        }
      }     
    })
    .state('app.workorders.complete', {
      url: "/complete",
      views: {
        'workorder-tab-complete' : {
          templateUrl: "views/partials/workorders/tab-workorder-complete.html"
        }
      }     
    })    
    .state('app.workorders.detail', {
      url: "/detail/:woid",
      views: {
        'workorder-tab-open' : {
          templateUrl: "views/partials/workorders/tab-workorder-open.html"
        }
      }
    })
    .state('app.workorder-photos', {
      url: "/workorders/:woid/photos",
      abstract: true
      views: {
        'menuContent' : {
          templateUrl: "views/workorders/workorder-photos.html"
          controller: 'WorkorderPhotosCtrl'
        }
      }
    })
    .state('app.workorder-photos.all', {
      url: "/all",
    })
    .state('app.workorder-photos.todo', {
      url: "/todo",
    })
    .state('app.workorder-photos.picks', {
      url: "/picks",
    })
    # demo only, set ACL to public
    .state('app.demo', {
      url: "/demo/:woid",
      abstract: false
      views: {
        'menuContent' : {
          templateUrl: "views/workorders/workorder-demo.html"
          controller: 'WorkorderPhotosCtrl'
        }
      }
    })
    .state('app.demo.all', {
      url: "/photos/all",
    })
    .state('app.demo.picks', {
      url: "/photos/picks",
    })
  # if none of the above states are matched, use this as the fallback
  $urlRouterProvider.otherwise('/app/top-picks/top-picks');  
  # $urlRouterProvider.otherwise('/app/settings');  

]
.controller 'AppCtrl', [
  '$scope', '$rootScope', '$state', '$timeout', '$q', 'angularLoad'
  '$ionicPlatform', '$ionicModal', '$ionicLoading'
  '$localStorage', 'otgLocalStorage'
  'SideMenuSwitcher', '$ionicSideMenuDelegate', 
  'otgParse', 'otgWorkorderSync'
  'snappiMessengerPluginService', 'i18n',
  'deviceReady', 'cameraRoll'
  'otgData', 'imageCacheSvc', 'appConsole'
  'pushNotificationPluginSvc', 'notifyService'
  # 'localNotificationPluginSvc'
  ($scope, $rootScope, $state, $timeout, $q, angularLoad
    $ionicPlatform, $ionicModal, $ionicLoading,
    $localStorage, otgLocalStorage
    SideMenuSwitcher, $ionicSideMenuDelegate, 
    otgParse, otgWorkorderSync
    snappiMessengerPluginService, i18n, 
    deviceReady, cameraRoll,
    # debug/browser only
    otgData, imageCacheSvc, appConsole  
    pushNotifyPlugin, notifyService
    # localNotifyPlugin
    )->

    # dynamically update left side menu
    $scope.SideMenuSwitcher = SideMenuSwitcher  
    SideMenuSwitcher.leftSide.src = 'views/partials/left-side-menu.html'


    # 
    # loading backdrop
    # 
       
    $scope.showLoading = (value = true, timeout=5000)-> 
      return $ionicLoading.hide() if !value
      $ionicLoading.show({
        template: '<ion-spinner class="spinner-light" icon="lines"></ion-spinner>'
        duration: timeout
      })
    $scope.hideLoading = (delay=0)->
      $timeout ()->
          $ionicLoading.hide();
        , delay 

    # Cordova splashscreen     
    $scope.hideSplash = ()->
      deviceReady.waitP()
      .then ()->
        navigator.splashscreen?.hide() if deviceReady.device().isDevice
        return

    window.i18n = $rootScope.i18n = $scope.i18n = i18n;

    # copy these to app scope
    ADD_TO_APP_SCOPE = {
      'deviceReady' : deviceReady 
      'cameraRoll' : cameraRoll 
      'i18n' : i18n
      '$ionicPlatform' : $ionicPlatform 
      '$ionicModal' : $ionicModal 
      '$ionicSideMenuDelegate' : $ionicSideMenuDelegate
      '$localStorage' : $localStorage
      'notifyService' : notifyService
    }
    _.extend $scope, ADD_TO_APP_SCOPE


    # prototypal inheritance, for access from child controllers
    $scope.app = {
      menu: (type='owner')->
        switch type
          when 'owner'
            SideMenuSwitcher.leftSide.src='views/partials/left-side-menu.html'
          when 'editor'
            SideMenuSwitcher.leftSide.src='views/partials/workorders/left-side-menu.html'
        $ionicSideMenuDelegate.toggleLeft()
        return

      localStorageSnapshot: ()->
        # cameraRoll
        $localStorage['cameraRoll'].map = cameraRoll.map()
        # imgCacheSvc.cacheIndex
        return

      toggleHelp : ()->
        $scope.config.help = !$scope.config.help  
        # console.log "help="+ if $scope.config.help then 'ON' else 'OFF'

      sync: 
        cameraRoll_Orders: ()-> 
          # console.log ">>> SYNC_cameraRoll_Orders"
          cameraRoll.loadCameraRollP(null, 'merge').finally ()->
            if !$scope.deviceReady.isOnline()
              $rootScope.$broadcast('sync.debounceComplete')
              msg = {
                title: "Warning: Device Offline"
                message: "No internet connection was detected."
              }
              notifyService.message msg, "warning", 5000
              return 
              
            otgWorkorderSync.SYNC_ORDERS(
              $scope, 'owner', 'force'
              , ()->
                $rootScope.$broadcast('sync.debounceComplete')
                return
            )
          return

        DEBOUNCED_cameraRoll_Orders: ()->
          debounced = _.debounce ()->
            # console.log "\n\n >>> DEBOUNCED_cameraRoll_Orders fired"
            $scope.app.sync.cameraRoll_Orders()
            return
          , 5000 # 5*60*1000
          , {
            leading: true
            trailing: false
          }
          debounced() # call immediately
          $scope.app.sync.DEBOUNCED_cameraRoll_Orders = debounced # save for future calls
          return


      # initial app preferences, priority to NSUserDefaults via plugin
      appPreferences : {
        store: (newVal, oldVal)->
          if plugins?.appPreferences?
            prefs = plugins.appPreferences
            ok = ()-> # appPreferences.store returns "OK"
              # console.log "NSUserDefaults save OK"
              # prefs.fetch okAlert, fail, 'prefs'
              return

            okAlert = (value)->
              # console.log "NSUserDefaults fetch SUCCESS: value=" + JSON.stringify value
              return  

            fail = (err)->
              console.warn "NSUserDefaults: error=" + JSON.stringify err
              return

            return prefs.store ok, fail, 'prefs', newVal
          else 
            # save to localStorage
            return
        load: ()->
          # for completeness only: $localStorage['config']  > appPreferences
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
    }

    # copy these to $rootScope scope, i.e. need access from directives, services, etc.
    ADD_TO_ROOT_SCOPE = {
      $state: $state
      user:  otgParse.mergeSessionUser()
      config: null
      counts: null
      device: null
      isStateWorkorder: ()->
        return true if $state.includes('app.workorders')
        return true if $state.includes('app.workorder-photos')
        return false      
    }
    _.extend $rootScope, ADD_TO_ROOT_SCOPE


    $rootScope.$watch 'user.tosAgree', (newVal, oldVal)->
      return if newVal == oldVal
      agreedOn = if newVal then new Date().toJSON() else null
      return if !agreedOn && !$rootScope.sessionUser
      return otgParse.updateUserProfileP({'tosAgree': agreedOn}).then null, (error)->
          console.log error

    # respond to changes of app.settings, BEFORE $localStorage['config'] 
    $scope.$watch 'config', (newVal, oldVal)->
        # console.log "app: upload=" + JSON.stringify newVal.upload
        return $scope.app.appPreferences['store'] newVal, oldVal
      , true

    $scope.$on 'user:sign-out', (args)->
      console.log "$broadcast user:sign-out received"
      _.extend $rootScope.counts, {
        'top-picks': 0
        uploaderRemaining: 0
        orders: 0
      }
      cameraRoll.loadCameraRollP(null, 'replace').then ()->
        $scope.app.localStorageSnapshot()
        return
      pushNotifyPlugin.registerP()
      return
    $scope.$on 'user:sign-in', (args)->
      console.log "$broadcast user:sign-in received"
      pushNotifyPlugin.registerP()
      otgWorkorderSync.clear()
      cameraRoll.clearPhotos_PARSE()  
      if deviceReady.device().isBrowser            
        cameraRoll.clearPhotos_CameraRoll()           
        # TODO: move to cameraRoll.clearPhotos_CameraRoll()
        $rootScope.$broadcast('sync.cameraRollComplete', {changed:true})
      if otgParse.isAnonymousUser() == false
        window.TEST_DATA = null 
      
      return


    $scope.$on 'sync.cameraRollComplete', (args)->
      $scope.app.localStorageSnapshot()

    $scope.$on 'sync.debounceComplete', ()->
        $scope.hideLoading()
        $rootScope.$broadcast('scroll.refreshComplete')
        $scope.app.localStorageSnapshot()
        return     

    $ionicPlatform.on 'pause',  ()-> 
      $scope.app.localStorageSnapshot()


    _RESTORE_FROM_LOCALSTORAGE = ()->
      try
        # config values read from localstorage, set in otgLocalStorage
        otgLocalStorage.loadDefaultsIfEmpty([
          'config', 'device', 'menuCounts'
          'topPicks'
          'cameraRoll'
        ]) 
        # do this BEFORE any listeners are registered
        if $localStorage['config']['upload']['auto-upload'] == false
          $localStorage['config']['upload']['enabled'] = false # force

        $rootScope.config =  $scope.config = $localStorage['config']
        $rootScope.counts = $localStorage['menuCounts']
        $rootScope.device = $localStorage['device']
        return
      catch e
        console.error "_RESTORE_FROM_LOCALSTORAGE, err=" + JSON.stringify e
      
      


    # Dev/Debug tools
    _LOAD_DEBUG_TOOLS = ()->
      try
        $scope.MessengerPlugin = snappiMessengerPluginService
        window.appConsole = $rootScope.appConsole = appConsole
      catch e
        console.error "_LOAD_DEBUG_TOOLS, err=" + JSON.stringify e


    _LOAD_BROWSER_TOOLS = ()->
      # skip if user signed in
      return if otgParse.isAnonymousUser() == false
      return if otgParse.isAnonymousUser() && cameraRoll.filterParseOnly().length

      # load TEST_DATA
      angularLoad.loadScriptP("js/services/test_data.js")  
      .then ()->
        return if !window.TEST_DATA
        TEST_DATA = window.TEST_DATA
        # TEST_DATA = window.TEST_DATA # load dynamically into global
        # console.log "\n\n *** loading TEST_DATA: TODO: MOVE TO _LOAD_BROWSER_TOOLS ***\n\n"
        cameraRoll.orders = TEST_DATA.orders
        photos_ByDateUUID = TEST_DATA.cameraRoll_byDate
        cameraRoll.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( photos_ByDateUUID ), 2
        _photos = otgData.parsePhotosFromMoments cameraRoll.moments, 'TEST_DATA'
        cameraRoll._mapAssetsLibrary = _.map _photos, (TEST_DATA_photo)->
          return {UUID: TEST_DATA_photo.UUID, dateTaken: TEST_DATA_photo.date}
        cameraRoll['iOSCollections'].mapP()
        # add some test data for favorite and shared
        TEST_DATA.addSomeTopPicks( cameraRoll.map())
        TEST_DATA.addSomeFavorites( cameraRoll.map())
        TEST_DATA.addSomeShared( cameraRoll.map())
        # add item.height for collection-repeat
        _.each cameraRoll.map(), (e,i,l)->
          e.originalHeight = if /^[EF]/.test(e.UUID) then 400 else 240
          e.originalWidth = 320
          e.dateTaken = e.date
          e.src = TEST_DATA.lorempixel.getSrc(e.UUID, e.originalWidth, e.originalHeight,TEST_DATA)
          return
        $scope.orders = TEST_DATA.orders
        $scope.app.sync.cameraRoll_Orders()
        # $rootScope.$broadcast('sync.TEST_DATA')

      # refactor to AppCtrl or service

      _readCookie = `function (k,r){return(r=RegExp('(^|; )'+encodeURIComponent(k)+'=([^;]*)').exec(document.cookie))?r[2]:null;}`
      
      _showTestDrive = ()->
         $ionicModal.fromTemplateUrl('partials/modal/test-drive', {
            scope: $scope,
            animation: 'slide-in-down'
          }).then( (modal)-> 
            $scope.modal.testdrive = self = modal
            self.show()
            window.testdrive = $scope.modal.testdrive

            self.scope.isModal = {
              type: 'testdrive'  # [terms-of-service | privacy]
              hide: ()->
                self.hide()
                self.remove()
              dontShowAgain: ()->
                $scope.config['dont-show-again']['test-drive'] = true
                document.cookie = 'dontShowTestDrive=true; expires=Wed, 01 Jan 2020 12:00:00 GMT; path=/';
                self.scope.isModal.hide()
            }
          ) 

      # check cookie for value
      $scope.config['dont-show-again']['test-drive'] = _readCookie('dontShowTestDrive')=='true'
      _showTestDrive() if !$scope.config['dont-show-again']['test-drive']
      return

    _LOAD_MODALS = ()->  
      try
        # ...
      
        #
        # app modals
        #
        $scope.modal = {
          legal: null
        }

        $ionicModal.fromTemplateUrl('views/settings-legal.html', {
            scope: $scope,
            animation: 'slide-in-up'
          }).then( (modal)-> 
            $scope.modal.legal = self = modal
            window.legal = $scope.modal.legal

            self.scope.isModal = {
              type: 'terms-of-service'  # [terms-of-service | privacy]
              hide: ()->
                self.hide()
            }
            self.showTab = (type)->
              self.scope.isModal.type = type
              self.show()
          ) 

        $scope.$on('$destroy', ()->
          $scope.modal.legal.remove();
          delete $scope.modal.legal
        ); 
      catch e
        console.error "_LOAD_MODALS, err=" + JSON.stringify e 


    init = ()->
      _RESTORE_FROM_LOCALSTORAGE()

      _LOAD_MODALS()

      _LOAD_DEBUG_TOOLS()

      deviceReady.waitP()
      .then ()->
        $scope.config['no-view-headers'] = deviceReady.device().isDevice && false
        $rootScope.device.id = deviceReady.device().id
        # console.log "\n\n>>> deviceId="+$rootScope.device.id
      .then ()-> # Device Init
        return if deviceReady.device().isBrowser
        # pushNotifications
        # console.log "$localStorage['device']=" + JSON.stringify $localStorage['device']  
        pushNotifyPlugin.initialize( $localStorage['device'] )
          .registerP()


        # loadMomentThumbnails on timer, cancel if done elsewhere
        # for reload cameraRoll.map() from localStorage
        _cancel = $timeout ()->
            cameraRoll.loadCameraRollP(null, false)
            return
          , 3000
        _off = $rootScope.$on 'cameraRoll.beforeLoadMomentThumbnails', (ev, cancel)->
          $timeout.cancel _cancel 
          _off()
          _off = _cancel = null
        return # restore cameraRoll.map snapshot
        
      .finally ()->
        if deviceReady.device().isBrowser
          # browser
          _LOAD_BROWSER_TOOLS() 
      
        # promise = otgWorkorderSync.SYNC_ORDERS($scope, 'owner', 'force') if !$rootScope.isStateWorkorder()
        promise = otgParse.checkBacklogP().then (backlog)->
          $scope.config.system['order-standby'] = backlog.get('status') == 'standby'
        return  # end $ionicPlatform.ready
      .catch (e)->
        console.error "init.deviceReady.waitP(), err=" + JSON.stringify e

    init()

    window.debug = _.extend window.debug || {} , {
      user: $rootScope.user
      cameraRoll: cameraRoll
      workorders: otgWorkorderSync._workorderColl
      woSync: otgWorkorderSync
      imgCache: imageCacheSvc
      ls: $localStorage
      pushNotify: pushNotifyPlugin
      # localNotify: localNotifyPlugin
    }

  ]