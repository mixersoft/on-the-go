'use strict'

###*
 # @ngdoc factory
 # @name onTheGo.backend.otgParse
 # @description 
 # methods for accessing parse javascript SDK
 # 
###



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

.factory 'otgWorkorderSync', [
  '$q', '$rootScope', '$timeout', 'deviceReady', 'otgParse', 'otgWorkorder', 'otgUploader', 'cameraRoll'
  ($q, $rootScope, $timeout, deviceReady, otgParse, otgWorkorder, otgUploader, cameraRoll )->

    self = {
      _workorderColl : {
        owner: []
        editor: []
      }
      _workorderPhotosColl: {
        # workorderObj.id: photosColl
      }

      clear: ()->
        self._workorderColl = {
          owner: []
          editor: []
        }
        self._workorderPhotosColl = {}
        cameraRoll.clearPhotos_PARSE()
        return

      ## @param: options, {type:[workorderObj, photosColl], role:[owner,editor], id: workorderObj.id:}
      getFromCache: (options)->
        switch options.type
          when 'workorderObj'
            role = options.role || 'owner'
            return self._workorderColl[role] if !option.id 
            return _.find self._workorderColl[role], {id: id}
          when 'photosColl'
            return _.find self._workorderPhotosColl, {id: id}


      fetchWorkordersP : (options={}, force)->

        role = if options.editor then 'editor' else 'owner'
        
        cached = self._workorderColl[role]
        return $q.when( cached ) if cached.length && !force

        return otgParse.checkSessionUserP().then ()->
          return otgParse.fetchWorkordersByOwnerP(options)
        .then (workorderColl)->
          self._workorderColl[role] = workorderColl
          console.log "\n *** fetchWorkordersP from backend.coffee, role=" + role
          return workorderColl

      fetchWorkorderPhotosP : (workorderObj,  options={}, force)->
        options = {owner: true} if _.isEmpty options

        cached = self._workorderPhotosColl[ workorderObj.id ] 
        return $q.when( cached ) if cached && !force

        return otgParse.checkSessionUserP().then ()->
          options = {
            workorder: workorderObj
            owner: true
          }
          return otgParse.fetchWorkorderPhotosByWoIdP(options)
        .then (photosColl)->
          self._workorderPhotosColl[ workorderObj.id ] 

          wo = workorderObj.toJSON()
          # patch workorder.selectedMoment AFTER workorder photos fetched
          # path MANUALLY because we don't have cameraRoll.moments
          # moments normally set in snappiMessengerPluginService.mapAssetsLibraryP()

          ### expecting:
          workorderMoment = {
            type:'moment'
            key:[date]
            value: [
              {
                type: 'date'
                key:[date]
                value: [
                  UUID, UUID
                ]
              }
            ]
          }
          ###
          
          workorderMoment = {
            type:'moment'
            key: wo.fromDate
            value: [
              {
                type: 'date'
                key: wo.fromDate
                value: _.pluck photosColl.toJSON(), 'UUID'
              }
            ]
          }

          workorderObj.set('workorderMoment', [ workorderMoment ] )
          # self.updateWorkorderCounts(woObj, workorderMoment) # do after resolve()

          # console.log " \n\n 1b: &&&&& fetchWorkorderPhotosP from backend.coffee "
          # console.log "\n\n*** inspect workorderMoment for Workorder: " 
          console.log workorderObj.toJSON()

          return photosColl

      queueMissingPhotos : (workorderObj, photosColl)->
        photos = photosColl.toJSON()

        console.log "\n\n workorder photo assetIds, length=" + photos.length
        uploadedAssetIds = _.pluck photos, 'assetId'

        # compare against selectedMoment UUIDs
        dateRange = otgWorkorder.on.selectByCalendar workorderObj.get('fromDate'), workorderObj.get('toDate')
        dateRange = {
          from: workorderObj.get('fromDate')
          to: workorderObj.get('toDate')
        }
        # compare vs. map because cameraRoll.photos is incomplete
        mappedPhotos = cameraRoll.map() 
        mappedPhotos = cameraRoll.photos if _.isEmpty mappedPhotos

        mappedAssetIdsFromWorkorderDateRange = _.reduce mappedPhotos, (result, o)->
            o.date = cameraRoll.getDateFromLocalTime o.dateTaken if !o.date
            result.push o.UUID if dateRange.from <= o.date <= dateRange.to
            return result
          , []

        console.log "workorder.count_expected="+mappedAssetIdsFromWorkorderDateRange.length

        ## move to self.updateWorkorderCounts(workorderObj, queue) 
        # if workorderObj.get('count_expected') != mappedAssetIdsFromWorkorderDateRange
        #   $timeout ()->return workorderObj.save {
        #         count_expected: mappedAssetIdsFromWorkorderDateRange.length
        #       }
        #     , 100



        missingPhotos = _.difference mappedAssetIdsFromWorkorderDateRange, uploadedAssetIds

        queue = otgUploader.queue(workorderObj, missingPhotos)
        console.log "workorder found and missing photos queued, length=" + queue.length
        return queue

      # wrap in timeouts 
      SYNC_ORDERS : (scope, force, DELAY=10, whenDoneP)->
        # run AFTER cameraRoll loaded
        # return if _.isEmpty $rootScope.sessionUser
        return if deviceReady.isWebView() && _.isEmpty cameraRoll.map()

        options = {
          role: 'owner'
          owner: true
        }

        $timeout ()->
            console.log "\n\n*** BEGIN Workorder Sync for role=" + options.role + "\n"
            self.fetchWorkordersP( options , force ).then (workorderColl)->

                promises = []
                scope.menu.orders.count = openOrders = 0
                workorderColl.each (workorderObj)->

                  return if workorderObj.get('status') == 'complete'
                  openOrders++
                  $timeout ()->
                      promises.push self.fetchWorkorderPhotosP(workorderObj, options, force ).then (photosColl)->

                        queue = self.queueMissingPhotos( workorderObj, photosColl )
                        self.updateWorkorderCounts(workorderObj, queue) # expect workorderObj.workorderMoment to be set
                        scope.menu.uploader.count = otgUploader.queueLength()

                        scope.workorders = workorderColl.toJSON()
                    , DELAY

                  scope.menu.orders.count = openOrders 
                  return
                $q.all( promises ).then (o)->
                  console.log "\n\n*** Workorder SYNC complete for role=" + options.role + "\n"
                  return whenDoneP(workorderColl) if whenDoneP
          , DELAY

      # wrap in timeouts 
      SYNC_WORKORDERS : (scope, force, DELAY=10, whenDoneP)->
        # run AFTER cameraRoll loaded
        return if _.isEmpty $rootScope.sessionUser
        return if deviceReady.isWebView() && _.isEmpty cameraRoll.map()

        options = {
          role: 'editor'
          editor: true
        }

        $timeout ()->
            console.log "\n\n*** BEGIN Workorder Sync for role=" + options.role + "\n"
            self.fetchWorkordersP( options , force ).then (workorderColl)->

                promises = []
                openOrders = 0
                workorderColl.each (workorderObj)->

                  return if workorderObj.get('status') == 'complete'
                  openOrders++
                  $timeout ()->
                      promises.push self.fetchWorkorderPhotosP(workorderObj, options, force ).then (photosColl)->
                        self.updateWorkorderCounts(workorderObj) # expect workorderObj.workorderMoment to be set
                        # fetch all workorder photos to set workorderMoment
                        # update workorder.selecteMoments
                        # TODO: save workorderMoment to workorderObj os we don't have to repeat
                        scope.workorders = workorderColl.toJSON()  
                        return photosColl
                    , DELAY

                  scope.menu.orders.count = openOrders 
                  return
                $q.all( promises ).then (o)->
                  scope.workorders = workorderColl.toJSON()  
                  console.log "\n\n*** Workorder SYNC complete for role=" + options.role + "\n"
                  return whenDoneP(workorderColl) if whenDoneP
          , DELAY

      updateWorkorderCounts: (woObj, missing)->
        updates = {}
        woMoment = woObj.get('workorderMoment') 
        received = woMoment[0].value[0].value.length if !_.isEmpty woMoment
        updates['count_received'] = received if woObj.get('count_received') != received
        updates['count_expected'] = missing.length + (updates['count_received'] || 0)  if missing?.length

        # count_duplicate: query(photosObj) by Owner and indexBy workorderObj.id

        return if _.isEmpty updates
        $timeout ()->
            return woObj.save( updates ) 
          , 100

    }
    return self

]

.factory 'otgParse', [
  '$q', '$ionicPlatform', '$timeout', '$rootScope', 'deviceReady', 'cameraRoll', 
  ($q, $ionicPlatform, $timeout, $rootScope, deviceReady, cameraRoll)->

    parseClass = {
      PhotoObj : Parse.Object.extend('PhotoObj',  {
          initialize: (attrs, options)->
            if options?.initClass == true
              console.log "\n\n\n >>>> PhotoObj initialize()\n"
              console.log attrs
              ## force PhotoObj attributes with first upload by adding classDefaults
              classDefaults = {
                dateTaken : new Date().toJSON()
                originalWidth : 0
                originalHeight : 0
                rating : 0
                favorite : false
                topPick: false
                shared: false
                caption : ''
                exif : {}
                shotId : '000'
                isBestshot: false
              }
              self = this
              _.each classDefaults, (v,k)->
                self.set(k,v)
              return self
        }
      ) 
      WorkorderObj : Parse.Object.extend('WorkorderObj') 
      
    }

    ANON_PREFIX = {
      username: 'anonymous-'
      password: 'password-'
    }


    self = {
      isAnonymousUser: ()->
        return true if _.isEmpty $rootScope.sessionUser
        return true if $rootScope.sessionUser.get('username').indexOf(ANON_PREFIX.username) == 0
        # return true if $rootScope.sessionUser.get('username') == 'browser'
        return false

      mergeSessionUser: (anonUser)->
        # merge from cookie into $rootScope.user
        $rootScope.sessionUser = Parse.User.current()
        return if !($rootScope.sessionUser instanceof Parse.Object)

        isRegistered = !self.isAnonymousUser()
        return anonUser if !isRegistered
        
        userCred = _.pick( $rootScope.sessionUser.toJSON(), ['username', 'email', 'emailVerified', 'tos', 'rememberMe'] )
        userCred.password = 'HIDDEN'
        userCred.isRegistered = true
        return _.extend anonUser, userCred




      signUpP: (userCred)->
        dfd = $q.defer()
        user = new Parse.User();
        user.set("username", userCred.username.toLowerCase())
        user.set("password", userCred.password)
        user.signUp null, {
            success: (user)->
              $rootScope.sessionUser = Parse.User.current()
              return dfd.resolve(userCred)
            error: (user, error)->
              $rootScope.sessionUser = null
              $rootScope.user.username = ''
              $rootScope.user.password = ''
              console.warn "parse User.signUp error, msg=" + JSON.stringify error
              return dfd.reject(userCred)
          }
        return dfd.promise

      loginP: (userCred)->
        if _.isArray(userCred)
          userCred = {
            username: $rootScope.user[userCred[0]]
            password: $rootScope.user[userCred[1]]
          }
        return deviceReady.waitP().then ()->
          return Parse.User.logIn( userCred.username.toLowerCase(), userCred.password )
        .then (user)->  
            $rootScope.sessionUser = Parse.User.current()
            $rootScope.user.isRegistered = true
            return user
        , (user, error)->
            $rootScope.sessionUser = null
            $q.reject("User login error. msg=" + JSON.stringify error)

      logoutSession: ()->
        Parse.User.logOut()
        _.extend $rootScope.user , {
          id: null
          username: null
          password: null
          email: null
          emailVerified: false
          tos: false
          rememberMe: false
          isRegistered: false
        }
        return $rootScope.sessionUser = Parse.User.current()

      anonSignUpP: (seed)->
        dfd = $q.defer()
        _uniqueId = (length=8) ->
          id = ""
          id += Math.random().toString(36).substr(2) while id.length < length
          id.substr 0, length
        seed = _uniqueId(8) if !seed
        anon = {
          username: ANON_PREFIX.username + seed
          password: ANON_PREFIX.password + seed
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

        # # upgrade to named user
        # if $rootScope.user.username? && $rootScope.user.username != $rootScope.sessionUser.get('username')
        #   _.each ['username', 'password', 'email'], (key)->
        #     $rootScope.sessionUser.set(key, $rootScope.user[key])
        #   $rootScope.sessionUser.save().then (user)->
        #       return $q.when(user)
        #     , (error)->
        #       throw error # end of line
        else 
          return $q.when({}) if self.isAnonymousUser()
          # copy sessionUser to local user
          userCred = _.pick( $rootScope.sessionUser.toJSON(), ['username', 'email', 'emailVerified'] )
          userCred.password = 'HIDDEN'
          _.extend $rootScope.user, userCred
          return $q.when(userCred)

      saveSessionUserP : (updateKeys)->
        _.each updateKeys, (key)->
            $rootScope.sessionUser.set(key, $rootScope.user[key])
        return $rootScope.sessionUser.save().then (user)->
            $rootScope.sessionUser = Parse.User.current()
            return $q.when($rootScope.sessionUser)
          , (error)->
            throw error # end of line

      checkSessionUserRoleP : (o)->
        # Placeholder: for workorders, check for role=EDITOR and Assignment
        o.role = 'EDITOR'
        return $q.when(o)



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

      _patchParsePhotos : (photosColl)->
        photosColl.each (photoObj)->
          # otgParse._patchParsePhotos(): patched attrs will be saved back to PARSE
          # cameraRoll.patchPhoto(): will just patch local attrs
          photoObj.set('UUID', photoObj.get('assetId') ) # DEPRECATE, use UUID on PARSE
          # photoObj.set('date', cameraRoll.getDateFromLocalTime( photoObj.get('dateTaken') ) )
          # photoObj.set('from', 'PARSE' )
          photo = photoObj.toJSON()
          photo.date = cameraRoll.getDateFromLocalTime(photo.dateTaken)
          photo.from = "PARSE"
          photo.UUID = photo.assetId if !photo.UUID
          cameraRoll.addOrUpdatePhoto_FromWorkorder photo

          return
        return 


      fetchWorkordersByOwnerP : (options={})->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('owner', $rootScope.sessionUser)
        if options.editor
          options.editor = $rootScope.sessionUser if options.editor == true
          console.warn "\n\n ***  WARNING: using workorder.owner as a proxy for workorder.editor for the moment\n"
          query.equalTo('owner', options.editor) 
        collection = query.collection()
        collection.comparator = (o)->
          return o.get('toDate')
        return collection.fetch()

      getWorkorderByIdP : (woid)->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('objectId', woid)
        return query.first()  

      fetchWorkorderPhotosByWoIdP : (options)-> 
        query = new Parse.Query(parseClass.PhotoObj)
        
        if options.workorder instanceof Parse.Object
          workorderObj = options.workorder
        else 
          # TODO: options.workorder.id or .UUID?
          # workorderObj.id == workorderObj.toJSON().objectId
          workorderObj = new Parse.Object('WorkorderObj', {
            id: options.workorder.objectId 
          })

        query.equalTo('workorder', workorderObj) 
        query.equalTo('owner', $rootScope.sessionUser) if options.owner
        if options.editor
          options.editor = $rootScope.sessionUser if options.editor == true
          console.warn "\n\n ***  WARNING: using workorder.owner as a proxy for workorder.editor for the moment\n"
          query.equalTo('owner', options.editor) 

        collection = query.collection()
        # collection.comparator = (o)->
        #   return o.get('toDate')
        return collection.fetch().then (photosColl)->
          # ???: patch photoObj means it will save to server
          # patch .toJSON() instead?
          self._patchParsePhotos(photosColl)
          return photosColl
          

      savePhotoP : (item, collection, pick)->
        photoObj = _.findWhere(collection.models, {id: item.objectId})
        return false if !photoObj
        data = _.pick item, pick
        photoObj.set(data)
        return photoObj.save()

      updatePhotoP: (photo, pick)->
        # find photoObj   
        query = new Parse.Query( parseClass.PhotoObj )
        query.equalTo 'assetId', photo.UUID
        query.first().then (photoObj)->
          update = _.pick photo, pick
          photoObj.save(update).then ()->
            update.UUID = photo.UUID
            console.log "\n\n ### PARSE: photoObj saved, attrs=" + JSON.stringify pick

      fetchPhotosByOwnerP : (owner)->
        owner = $rootScope.sessionUser if !owner
        query = new Parse.Query(parseClass.PhotoObj)
        query.equalTo('owner', $rootScope.sessionUser)
        collection = query.collection()
        collection.comparator = (a, b)->
          # sort by mostRecent
          return -1 if a.createdAt > b.createdAt 
          return 1 if a.createdAt < b.createdAt
          return 0
        return collection.fetch().then (photosColl)->
          self._patchParsePhotos(photosColl)
          return photosColl


      saveParseP : (obj, data)->
        # simple pass thru
        return obj.save(data)
        

      resampleP : (imgOrSrc, W=320, H=null)->
        return $q.reject('Missing Image') if !imgOrSrc
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

      uploadFileP : (base64src, photo)->
        if /^data:image/.test(base64src)
          mimeType = base64src[10..20]
          ext = 'jpg' if (/jpg|jpeg/i.test(mimeType))   
          ext = 'png' if (/png/i.test(mimeType)) 
          filename = photo.UUID[0...36] + '.' + ext

          console.log "\n\n >>> Parse file save, filename=" + filename
          console.log "\n\n >>> Parse file save, dataURL=" + base64src[0..50]

          # get mimeType, then strip off mimeType, as necessary
          base64src = base64src.split(',')[1] 
        else 
          ext = 'jpg' # just assume

        # save DataURL as image file on Parse
        parseFile = new Parse.File(filename, {
            base64: base64src
          })
        return parseFile.save()
  

      uploadPhotoP : (workorder, photoOrMapItem)->
        UPLOAD_IMAGE_SIZE = 'preview'

        # # upgrade to named user
        # if $rootScope.sessionUser.get('username') != $rootScope.user.username
        #   _.each ['username', 'password', 'email'], (key)->
        #     $rootScope.sessionUser.set(key, $rootScope.user[key])
        photo = if photoOrMapItem?.UUID then photoOrMapItem else { UUID:photoOrMapItem }
        return throw "ERROR: cannot upload without valid workorder" if !workorder
        return deviceReady.waitP().then self.checkSessionUserP() 
          .then ()->
            if deviceReady.isWebView()
              # FORCE dataURL, do NOT use stashed File
              # found = cameraRoll.getDataURL(photo.UUID, UPLOAD_IMAGE_SIZE)
              # if found
              #   photo = _.find cameraRoll.photos, {UUID: photo.UUID}
              #   # photo is set by closure
              #   return found # is a dataURL

              # fetch with promise
              return cameraRoll.getDataURL_P( photo.UUID, UPLOAD_IMAGE_SIZE, 'dataURL' ).then (oPhoto)->
                dataURL = oPhoto.data
                console.log "\n*** cameraRoll.getDataURL_P() resolved with:" + dataURL[0...50]
                
                photo = _.find cameraRoll.photos, {UUID: oPhoto.UUID}
                # photo is set by closure
                throw "ERROR in uploadPhotoP, photo not found" if !photo 

                return dataURL

            # browser with dataURL
            photo = _.find cameraRoll.photos, {UUID: photo.UUID}
            if /^data:image/.test( photo.src )
              dataURL = photo.src
              return $q.when( dataURL )

            return self.resampleP(photo.src, 320)
            # should reject because of SecurityError
          .then (base64src)->
              # console.log "\n\n *** base64src=" + base64src[0...50]
              # console.log photo # $$$
              return self.uploadFileP(base64src, photo)
            , (error)->
              if error == 'Missing Image' || error.name == "SecurityError" && _.isString error.src
                fakeParseFile = {
                  url: ()-> return error.src
                }
                return $q.when fakeParseFile
              else 
                throw error
          .then (parseFile)->
              console.log "\n *** parseFile uploaded, check url=" + parseFile.url()

              extendedAttrs = _.pick photo, ['dateTaken', 'originalWidth', 'originalHeight', 'rating', 'favorite', 'caption', 'exif', 'orientation']
              # console.log extendedAttrs

              parseData = _.extend {
                    assetId: photo.UUID  # deprecate
                    UUID: photo.UUID
                    owner: $rootScope.sessionUser
                    workorder : workorder
                    deviceId: $rootScope.deviceId
                    src: parseFile.url()
                  }
                , extendedAttrs # , classDefaults

              photoObj = new parseClass.PhotoObj parseData , {initClass: false }
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
