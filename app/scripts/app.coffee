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
  # 'ionBlankApp.controllers',
  # 'ngAnimate',
  # 'ngCookies',
  # 'ngResource',
  # 'ngRoute',
  # 'ngSanitize',
  # 'ngTouch'
])
.constant('version', '0.0.1')
.run ['$rootScope', '$state', '$stateParams', '$ionicPlatform', ($rootScope, $state, $stateParams, $ionicPlatform)->
    $ionicPlatform.ready ()->
      # Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
      # for form inputs)
      cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true) if window.cordova?.plugins.Keyboard
      # org.apache.cordova.statusbar required
      StatusBar.styleDefault() if window.StatusBar?

    $rootScope.$state = $state;
    $rootScope.$stateParams = $stateParams;  
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

    # .state('app.search', {
    #   url: "/search",
    #   views: {
    #     'menuContent' : {
    #       templateUrl: "templates/search.html"
    #     }
    #   }
    # })

    # .state('app.browse', {
    #   url: "/browse",
    #   views: {
    #     'menuContent' : {
    #       templateUrl: "templates/browse.html"
    #     }
    #   }
    # })
    # .state('app.playlists', {
    #   url: "/playlists",
    #   views: {
    #     'menuContent' : {
    #       templateUrl: "templates/playlists.html",
    #       controller: 'PlaylistsCtrl'
    #     }
    #   }
    # })

    # .state('app.single', {
    #   url: "/playlists/:playlistId",
    #   views: {
    #     'menuContent' : {
    #       templateUrl: "templates/playlist.html",
    #       controller: 'PlaylistCtrl'
    #     }
    #   }
    # })
  # if none of the above states are matched, use this as the fallback
  $urlRouterProvider.otherwise('/app/top-picks');  


.controller 'AppCtrl', [
  '$scope', '$ionicModal', '$timeout', '$q', '$ionicPlatform', 'otgData', 'otgWorkOrder', 'TEST_DATA',
  ($scope, $ionicModal, $timeout, $q, $ionicPlatform,  otgData, otgWorkOrder, TEST_DATA)->
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

    }
    $scope.user = {
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

    $scope.orders = [] # order history


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
            # alert "SUCCESS: value=" + JSON.stringify value
            prefs.fetch okAlert, fail, 'prefs'
            return

          okAlert = (value)->
            alert "SUCCESS: value=" + JSON.stringify value
            return  

          fail = (err)->
            console.warn "FAIL: error=" + JSON.stringify err
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

    init = ()->
      $timeout ()->
          $ionicPlatform.ready ()->
            _prefs.load().then (config)->
              if config?.status == "PLUGIN unavailable"
                console.log config.status
              else if config?.status == "EMPTY"
                alert "config=" + JSON.stringify config
                _prefs.store $scope.config
              else 
                alert "config=" + JSON.stringify config
                _.extend $scope.config, config
              return
            return
        , 5000
      cameraRoll_DATA.photos_ByDate = TEST_DATA.cameraRoll_byDate
      cameraRoll_DATA.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate( cameraRoll_DATA.photos_ByDate ), 2
      cameraRoll_DATA.photos = otgData.parsePhotosFromMoments cameraRoll_DATA.moments

      # add some test data for favorite and shared
      TEST_DATA.addSomeFavorites( cameraRoll_DATA.photos)
      TEST_DATA.addSomeShared( cameraRoll_DATA.photos)
      # add item.height for collection-repeat
      _.each $scope.cameraRoll_DATA.photos, (e,i,l)->
        e.height = if e.id[-5...-4]<'4' then 400 else 240
        # e.height = 240
        e.src = "http://lorempixel.com/"+(320)+"/"+(e.height)+"?"+e.id
        return

      # otgWorkOrder methods need access to library of moments
      otgWorkOrder.setMoments(cameraRoll_DATA.moments)
      $scope.orders = TEST_DATA.orders

    init()

    window.debug = _.extend window.debug || {} , {
      user: $scope.user
      moments: cameraRoll_DATA.moments
      orders: $scope.orders
    }

  ]