angular
.module 'onTheGo.backend', []
.value 'PARSE_CREDENTIALS', {
  APP_ID : "cS8RqblszHpy6GJLAuqbyQF7Lya0UIsbcxO8yKrI"
  JS_KEY : "1QEOyaNj67lA58AH3xFE0Mu5MJsDCzlOZ3efFm47"
  REST_API_KEY : "3n5AwFGDO1n0YLEa1zLQfHwrFGpTnQUSZoRrFoD9"
}
# .service 'parseService', [
#   '$q', 'PARSE_CREDENTIALS'
#   ($q, PARSE_CREDENTIALS)->
#     this._initialized = false
#     this.init = ()->
#       return true if this.initialized
#       # //Initialize Parse
#       Parse.initialize(PARSE_CREDENTIALS.APP_ID,PARSE_CREDENTIALS.JS_KEY);
#       return this.initialized = true
#     return
# ]
.factory 'otgRestApi', [
  '$http', 'PARSE_CREDENTIALS'
  ($http, PARSE_CREDENTIALS)->
    parseHeaders_GET = {
        'X-Parse-Application-Id': PARSE_CREDENTIALS.APP_ID,
        'X-Parse-REST-API-Key':PARSE_CREDENTIALS.REST_API_KEY,
    }
    parseHeaders_SET = _.defaults { 'Content-Type':'application/json' }, parseHeaders_GET
    self = {
        getAll: (className)->
            return $http.get('https://api.parse.com/1/classes/' + className, {
              headers: parseHeaders_GET
            })
        get: (className, id)->
            return $http.get('https://api.parse.com/1/classes/' + className + '/' + id, {
              headers: parseHeaders_GET
            })
        create: (className, data)->
            return $http.post('https://api.parse.com/1/classes/' + className, data, {
              headers: parseHeaders_SET
            })
        edit: (className, id, data)->
            return $http.put('https://api.parse.com/1/classes/' + className + '/' + id, data, {
              headers: parseHeaders_SET
            });
        delete: (className, id)->
            return $http.delete('https://api.parse.com/1/classes/' + className + '/' + id, {
              headers: parseHeaders_SET
            })
    }
    return self
]

.factory 'otgParse', [
  '$q', '$ionicPlatform', '$timeout', '$rootScope'
  ($q, $ionicPlatform, $timeout, $rootScope)->

    # wrap $ionicPlatoform ready in a promise
    _deviceready = {
      promise : null
      cancel: null
      promise: null
      timeout: 5000
      check: ()->
        return _deviceready.promise if _deviceready.promise
        deferred = $q.defer()
        _deviceready.cancel = $timeout ()->
            return deferred.reject("ERROR: ionicPlatform.ready does not respond")
          , _deviceready.timeout
        $ionicPlatform.ready ()->
          $timeout.cancel _deviceready.cancel
          console.log "$ionicPlatform reports deviceready"
          return deferred.resolve("deviceready")
        return _deviceready.promise = deferred.promise
    }

    parseUser = {
      anonymous: 
        username: 'anonymous'
        password: 'dfgkj439gdlkHGW&v*634lkjg9S'
    }

    PhotoObj = Parse.Object.extend('PhotoObj')  

    self = {
      deviceReadyP: _deviceready.check()
      signUpP: (userCred)->
        dfd = $q.defer()
        user = new Parse.User();
        user.set("username", userCred.username)
        user.set("password", userCred.password)
        user.signUp null, {
            success: (user)->
              $rootScope.sessionUser = Parse.User.current()
              return dfd.resolve(userCred)
            error: (user, error)->
              $rootScope.sessionUser = null
              console.warn "parse User.signUp error, msg=" + JSON.stringify error
              return dfd.reject(userCred)
          }
        return dfd.promise

      loginP: (userCred)->
        dfd = $q.defer()
        Parse.User.logIn userCred.username, userCred.password, {
            success: (user)->
              $rootScope.sessionUser = Parse.User.current()
              return dfd.resolve(userCred)
            error: (user, error)->
              $rootScope.sessionUser = null
              console.warn "parse User.login error, msg=" + JSON.stringify error
              return dfd.reject(userCred)
          } 
        return dfd.promise

      anonSignUpP: (seed)->
        dfd = $q.defer()
        _uniqueId = (length=8) ->
          id = ""
          id += Math.random().toString(36).substr(2) while id.length < length
          id.substr 0, length
        seed = _uniqueId(8) if !seed
        anon = {
          username: 'anonymous-'+seed
          password: 'password-'+seed
        }
        self.signUpP(anon).then (userCred)->
              return dfd.resolve(userCred)
            , (error)->
              return dfd.reject "parseUser anonSignUpP() FAILED" 
        return dfd.promise


      resizeP: (o)->
        # placeholder 
        return $q.when(o)

      resampleP : (imgOrSrc, W=320, H=null)->
        console.log "*** resize & convert to base64 using Resample.js ******* imgOrSrc=" + imgOrSrc
        dfd = $q.defer()
        done = (dataURL)->
          console.log "resampled data=" + JSON.stringify {
            size: dataURL.length
            data: dataURL[0..60]
          }
          dfd.resolve(dataURL)
          return
        try 
          Resample.one()?.resample imgOrSrc
            ,   W
            ,   H    # targetHeight
            ,   dfd
            ,   "image/jpeg"
        catch ex  
          dfd.reject(imgOrSrc)
        return dfd.promise

      uploadFileP : (base64src, photo, belongsTo78)->
        filename = photo.id.substr(0, photo.id.lastIndexOf(".")) + ".jpg"
        # must end in '.jpg'
        parseFile = new Parse.File(filename, {
            base64: base64src
          })
        return parseFile.save()
  

      uploadPhotoP : (photo)->
        # see otgData for Photo properties
        if _.isEmpty($rootScope.sessionUser)
          if $rootScope.user.username? && $rootScope.user.password?
            authPromise = self.loginP($rootScope.user).then null
                , (error)->
                  userCred = error
                  return self.signUpP($rootScope.user)
          else 
            authPromise = self.anonSignUpP()
          return authPromise.then (userCred)->
              self.uploadPhotoP(photo) if $rootScope.sessionUser

        # upgrade to named user
        if $rootScope.sessionUser.get('username') != $rootScope.user.username
          _.each ['username', 'password', 'email'], (key)->
            $rootScope.sessionUser.set(key, $rootScope.user[key])


        return self.deviceReadyP.then ()->
            return self.resampleP(photo.src, 320)
          .then (base64src)->
              return self.uploadFileP(base64src, photo)
            , (error)->
              if error.name == "SecurityError" && _.isString error.src
                fakeParseFile = {
                  url: ()-> return error.src
                }
                return $q.when fakeParseFile
              else 
                throw error
          .then (parseFile)->
              parseData = _.extend {
                    assetId: photo.id
                    user: $rootScope.sessionUser
                    deviceId: '123'
                    src: parseFile.url()
                  }
                , _.pick photo, ['dateTaken', 'rating', 'favorite', 'caption', 'exif']
              photoObj = new PhotoObj(parseData)
              return photoObj.save()
            , (err)->
              console.warn "ERROR: parseFile.save() JPG file, err=" + JSON.stringify err
          .then (o)->
            console.log "photoObj.save() complete: " + JSON.stringify o
    }
    return self
]




### sessionUser
  register anonymous user
  get user prefs
  upgrade to current user
###

###
Parse.User
  preferences
Parse.Config: App config, enable A/B testing 


###
    # ParseClasses = {
    #   User:
    #     id:
    #     username:
    #     password:
    #     email:
    #     emailVerified:
    #     preferences:
    #       tos: false
    #       rememberMe: false
    #       help: false
    #       privacy: {}
    #       upload:
    #         autoUpload: false
    #         useCellularData: false
    #         use720pService: true
    #       archive:
    #         copyTopPicks: false
    #         copyFavorites: true
    #       sharing:
    #         user720pSharing: false
    #       dontShowAgain:
    #         topPicks: false
    #           topPicks: false
    #           favorite: false
    #           shared: false
    #         choose:
    #           cameraRoll: false
    #           calendar: false
    #   Device:
    #     id:
    #     ownerId:
    #     label: 

    #   Config:
    #     backgroundImage:
    #     sampleData:
    #     welcome
    #       message:
    #       walkthru:
    #     offers:

    #   Photo:
    #     id:
    #     ownerId:
    #     deviceId:
    #     workorderId:
    #     exif:
    #     dateTaken:
    #     label:
    #     rating:
    #     score: 
    #     topPick:
    #     favorite: 
    #     src:

    #   Workorder:
    #     id:
    #     ownerId: hasOne
    #     contributors: hasMany
    #     devices: hasMany
    #     photos: hasMany
    #     accessors: hasMany
    #     editorId: hasOne 
    #     status:
    #     timestamps:
    #       started:
    #       lastAction:
    #       finished:
    #       approved:
    #     elapsed:
    # }
