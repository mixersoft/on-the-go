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
          # $rootScope.deviceId = $cordovaDevice.getUUID()
          device = ionic.Platform.device()
          $rootScope.deviceId = device.uuid if device.uuid
          console.log "$ionicPlatform reports deviceready, device.UUID=" + $rootScope.deviceId
          return deferred.resolve("deviceready")
        return _deviceready.promise = deferred.promise
    }

    parseClass = {
      PhotoObj : Parse.Object.extend('PhotoObj') 
      WorkorderObj : Parse.Object.extend('WorkorderObj') 
      
    }


    self = {
      deviceReadyP: _deviceready.check
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

      logoutSession: ()->
        Parse.User.logOut()
        return $rootScope.sessionUser = Parse.User.current()

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

      checkSessionUserP: ()-> 
        if _.isEmpty($rootScope.sessionUser)
          if $rootScope.user.username? && $rootScope.user.password?
            authPromise = self.loginP($rootScope.user).then null
                , (error)->
                  userCred = error
                  return self.signUpP($rootScope.user)
          else 
            authPromise = self.anonSignUpP()
          authPromise.then ()->
              return self.checkSessionUserP() # check again
            , (error)->
              throw error # end of line

        # upgrade to named user
        if $rootScope.user.username? && $rootScope.user.username != $rootScope.sessionUser.get('username')
          _.each ['username', 'password', 'email'], (key)->
            $rootScope.sessionUser.set(key, $rootScope.user[key])
          $rootScope.sessionUser.save().then ()->
              return $q.when()
            , (error)->
              throw error # end of line
        else 
          return $q.when()

      findWorkorderP : (options)->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('owner', $rootScope.sessionUser)
        # # or query on relation
        # contributors = parseClass.workorderObj.getRelation('contributors')
        # contrib = new Parse.Query(contributors)
        query.equalTo('status', options.status) if options.status
        query.equalTo('fromDate', options.dateRange.from) if options.dateRange
        query.equalTo('fromDate', options.fromDate) if options.fromDate
        query.equalTo('toDate', options.dateRange.to) if options.dateRange
        query.equalTo('toDate', options.toDate) if options.toDate
        return query.find()


      createWorkorderP : (checkout, servicePlan)->
        parseData = {
          owner: $rootScope.sessionUser
          deviceId: $rootScope.deviceId
          # contributors: [$rootScope.sessionUser]
          # accessors: []
          fromDate: checkout.dateRange.from
          toDate: checkout.dateRange.to
          devices: [$rootScope.deviceId]
          count_expected: checkout.count.photos || 0 
          count_received: 0
          count_duplicate: 0
          count_days: checkout.count.days 
          servicePlan: servicePlan
          editor: null 
          status: 'new'
          startedAt: null
          finishedAt: null
          approvedAt: null
          lastActionAt: null
          elapsed: 0
        }
        workorderObj = new parseClass.WorkorderObj(parseData)
        workorderObj.relation('accessors').add($rootScope.sessionUser)
        workorderObj.relation('contributors').add($rootScope.sessionUser)
        return workorderObj.save().then null, (error)->
          console.error "parse WorkorderObj save error, msg=" + JSON.stringify error
          throw error

      fetchWorkordersByOwnerP : ()->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('owner', $rootScope.sessionUser)
        collection = query.collection()
        collection.comparator = (o)->
          return o.get('toDate')
        return collection.fetch()

          
        

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
  

      uploadPhotoP : (workorder, photo)->
        # see otgData for Photo properties
        # if _.isEmpty($rootScope.sessionUser)
        #   if $rootScope.user.username? && $rootScope.user.password?
        #     authPromise = self.loginP($rootScope.user).then null
        #         , (error)->
        #           userCred = error
        #           return self.signUpP($rootScope.user)
        #   else 
        #     authPromise = self.anonSignUpP()
        #   return authPromise.then (userCred)->
        #       self.uploadPhotoP(photo) if $rootScope.sessionUser

        # # upgrade to named user
        # if $rootScope.sessionUser.get('username') != $rootScope.user.username
        #   _.each ['username', 'password', 'email'], (key)->
        #     $rootScope.sessionUser.set(key, $rootScope.user[key])
        return throw "ERROR: cannot upload without valid workorder" if !workorder
        return self.deviceReadyP()
          .then self.checkSessionUserP() 
          .then ()->
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
                    owner: $rootScope.sessionUser
                    workorder : workorder
                    deviceId: $rootScope.deviceId
                    src: parseFile.url()
                  }
                , _.pick photo, ['dateTaken', 'rating', 'favorite', 'caption', 'exif']
              photoObj = new parseClass.PhotoObj(parseData)
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
