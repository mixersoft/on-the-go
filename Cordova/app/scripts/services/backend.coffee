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
  '$q', '$rootScope', '$timeout', 'deviceReady', 'otgParse', 'otgWorkorder', 'otgUploader', 'cameraRoll', 'imageCacheSvc'
  ($q, $rootScope, $timeout, deviceReady, otgParse, otgWorkorder, otgUploader, cameraRoll, imageCacheSvc )->

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

        return otgParse.checkSessionUserP(null, false)
        .then ()->
          if options.acl
            return otgParse.fetchWorkordersByACLP(options)
          else 
            return otgParse.fetchWorkordersByOwnerP(options)
        .then (workorderColl)->
            self._workorderColl[role] = workorderColl
            # console.log "\n *** fetchWorkordersP from backend.coffee, role=" + role

            # initialize if necessary
            workorderColl.each (wo)->
              woProgress = wo.get('progress')
              return if !_.isEmpty woProgress
              woProgress = {
                picks: 0
                todo: wo.get('count_expected')
              }
              wo.set('progress', woProgress)
              return

            return workorderColl
          , (err)->
            console.warn "\n *** fetchWorkordersP catch, role=" + role
            console.warn err

      fetchWorkorderPhotosP : (workorderObj,  options={}, force)->
        options.owner == true if $rootScope.user.role == 'owner'

        cached = self._workorderPhotosColl[ workorderObj.id ] 
        return $q.when( cached ) if cached && !force

        return otgParse.checkSessionUserP(null, false)
        .then ()->
          options.workorder = workorderObj
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

            # console.log " \n\n 1b: &&&&& fetchWorkorderPhotosP from backend.coffee "
            # console.log "\n\n*** inspect workorderMoment for Workorder: " 
            # console.log workorderObj.toJSON()

            return photosColl
          , (err)->
            return $q.reject(err)


      # replaces queueMissingPhotos
      syncWorkorderPhotosP : (workorderObj, photosColl, role='owner')->
        dateRange = {
          workorderObj: workorderObj
          from: workorderObj.get('fromDate')
          to: workorderObj.get('toDate')
        }

        # for displaying existing workorders in app.choose.cameraRoll otgMoment
        otgWorkorder.existingOrders.addExistingOrder(dateRange) if role=='owner'

        self.syncDateRange_Photos_P(dateRange, photosColl, role) 
        .then (sync)->
          # sync Parse.PhotoObj rows for WorkorderObj
          promises = {
            add: []
            remove: [] 
          }
          if !_.isEmpty sync['remove']
            $timeout ()->
              # move to otgParse.remove(assetIds)
              _.each sync['remove'], (UUID)->
                promises['remove'].push otgParse.updatePhotoP({UUID:UUID,remove:true}, 'remove')
                # unscheduleFile
                return

          if !_.isEmpty sync['add']
            mappedPhotos = cameraRoll.map()
            # move to otgParse.add(assetIds)
            
            _.each sync['add'], (UUID)->
              # find the photo, if we have it
              # WARNING: originalWidth/Height from map() may not be auto-rotated!!!!!
              found = _.find mappedPhotos, {UUID: UUID}
              promises['add'].push otgParse.uploadPhotoMetaP(workorderObj, found).then (o)->
                        sync['queued'].push found.UUID
                        return found
                      , (err)->
                        sync['errors'].push found.UUID
                        return found
              return
              # # use this is originalWidth/Height is not autoRotated
              # p = $q.when(found).then (found)->
              #     if !found
              #       return cameraRoll.getPhoto_P( UUID, {size: self.UPLOAD_IMAGE_SIZE}) 
              #     return found
              #   .then (found)->
              #     if !found 
              #       return {
              #         error: "ERROR: otgWorkorderSync trying to add UUID not found in cameraRoll. deleted?, UUID=" + UUID
              #       }
              #     if found.src == 'queued' 
              #       found.status = 'queued' 
              #       # skip, photoMeta already uploaded. move to top???
              #       return found 
              #     return otgParse.uploadPhotoMetaP(workorderObj, found).then (o)->
              #           found.status = 'queued'
              #           return found
              #         , (err)->
              #           found.status = 'error: photo meta'
              #           return found
              # promises.push p                
              # return 
          cleanupP = []
          if promises['remove'].length
            cleanupP.push $q.all(promises['remove']).then (removed)->
              sync['removed'] = removed
              sync['remove'] = []
              return sync

          if promises['add'].length
            cleanupP.push $q.all(promises['add']).then (added)->
              sync['added'] = added
              sync['add'] = []
              return sync
          
          if cleanupP.length
            return $q.all(cleanupP).then ()->
              return sync
          else 
            return $q.when sync
        .then (sync)->
          # upload/remove parseFiles, using either JS API or bkg-uploader
          return sync if deviceReady.device().isBrowser
          return self.queueDateRangeFilesP( sync ).then (resp)->
            # console.log "\n\n *** syncWorkorderPhotosP: sync complete for dataRange="+JSON.stringify( _.omit dateRange, 'workorderObj' )
            return sync
        .catch (err)->
          console.warn "\n\nError: syncWorkorderPhotosP: "+ JSON.stringify err

      ### 
      syncDateRange_PhotosP(dateRange).then
       resp = {
        add: [assetIds]     # in cameraRoll but NOT PhotoObj
        remove: [assetIds]     # in cameraRoll but NOT PhotoObj
        queued: [assetIds]  # PhotoObj.src == 'queued'
        errors: [assetIds]  # PhotoObj.src[0...5] == 'error' or 'Base6'
        complete: [assetIds] # complete
      }
      ###
      syncDateRange_Photos_P: (dateRange, photosColl, role='owner')->
        parseSync = {
          'woid': dateRange.workorderObj?.id
          'add' : []
          'remove' : []
          'complete': []
          'queued': []
          'errors': []
        }
        parsePhotos = photosColl?.toJSON?() || []
        checkDeviceId = deviceReady.device().isDevice && $rootScope.isStateWorkorder() == false
        if checkDeviceId == false
          promise = $q.when()
          # add, remove = [] for workorder syncs...
        else 
          parsePhotos = _.filter parsePhotos, (photo)->
              return photo.deviceId == $rootScope.device.id
          promise = cameraRoll.mapP(null, false).then (mappedPhotos)->

            cameraRollInDateRange = _.filter mappedPhotos, (o)->
              o.date = cameraRoll.getDateFromLocalTime o.dateTaken if !o.date
              return false if o.from?.slice(0,5)=='PARSE' 
              return dateRange.from <= o.date <= dateRange.to

            cameraRollAssetIds = _.pluck(cameraRollInDateRange, 'UUID')
            parseAssetIds = _.pluck( parsePhotos,'UUID' )

            parseSync['add'] = _.difference cameraRollAssetIds, parseAssetIds
            parseSync['remove'] = _.difference parseAssetIds, cameraRollAssetIds
            return
        
        return promise.then ()->
          if parseSync['remove'].length
            parsePhotos = _.filter parsePhotos, (o)->
              return true if parseSync['remove'].indexOf(o.UUID) == -1
              return false

          lastUploadDate = ''
          _.each parsePhotos, (o)->
            lastUploadDate = o.createdAt if o.createdAt > lastUploadDate

            parseSync['complete'].push( o.UUID ) if o.src[0...4] == 'http'
            parseSync['queued'].push( o.UUID ) if o.src == 'queued'
            # parse photoObj.src errors
            parseSync['errors'].push( o.UUID ) if o.src[0...5] == 'error'
            # getPhotoById errors
            parseSync['errors'].push( o.UUID ) if o.src[0...6] == 'Base64' 
            parseSync['errors'].push( o.UUID ) if o.src == "Not found!"
            return 
          parseSync['lastUploadDate'] = lastUploadDate
          return parseSync


      queueDateRangeFilesP: (sync, retryErrors=true)-> 
        # sync: # see syncDateRange_Photos_P()
          # 'add': 
          # 'remove':
          # 'complete':
          # 'queued':
          # 'errors':
        return otgUploader.uploader.getQueueP()
        .then (queuedAssetIds)->
          dfd = $q.defer()
          sync['addFile'] = _.difference sync['queued'], queuedAssetIds
          sync['addFile'] = sync['addFile'].concat _.difference sync['errors'], queuedAssetIds if retryErrors

          promise = otgUploader.uploader.queueP( sync )
          .then (resp)->
            return dfd.resolve(sync)
          .catch (err)->
            return dfd.reject(err)
          return dfd.promise

      _PATCH_DeviceId_OneWorkorder_P: (localPhotos, workorderObj, parsePhotosColl)->
        changed = {}
        update = {deviceId: $rootScope.device.id}
        pr1 = if _.isEmpty parsePhotosColl then  self.fetchWorkorderPhotosP(workorderObj)  else $q.then(parsePhotosColl)
        return pr1.then (photosColl)->
          # find photos that are on local device
          # localPhotoUUIDs = _( cameraRoll.map() ).filter( (o)->return !o.from || o.from.slice(0,5)!='PARSE' ).pluck('UUID').value()

          localPhotoUUIDs = _.pluck localPhotos, 'UUID'
          woPhotoUUIDs = photosColl.pluck 'UUID'
          overlapUUIDs = _.intersection localPhotoUUIDs, woPhotoUUIDs

          promises = []
          if !_.isEmpty(overlapUUIDs)
            photosColl.each (ph)->
              return if overlapUUIDs.indexOf( ph.attributes.UUID ) == -1
              oldDeviceId = ph.attributes.deviceId
              return if oldDeviceId == update.deviceId
              changed[oldDeviceId] = []
              pr2 = ph.save(update).then (o)->
                  changed[oldDeviceId].push o.attributes.UUID
                  # console.log "\n\n *** _PATCH_DeviceId changed, UUID=" + o.attributes.UUID
                  return 
                , (err)->
                  changed[oldDeviceId].push 'error'
                  console.warn "\n\n *** _PATCH_DeviceId, error: "+JSON.stringify err
                  return
              promises.push pr2
              return 

          return $q.all(promises)
          .then ()->
              # update workorder
              woUpdate = {}
              oldDeviceId = workorderObj.get('deviceId')

              if !_.isEmpty changed
                oldDeviceIds_ChangedPhotos = _.keys(changed)
                if oldDeviceIds_ChangedPhotos.indexOf(oldDeviceId) > -1
                  woDevices = _.difference workorderObj.get('devices'), oldDeviceIds_ChangedPhotos
                  woDevices.push update.deviceId
                  woUpdate['deviceId'] = update.deviceId
                  woUpdate['devices'] = woDevices
              else if workorderObj.get('owner').id == $rootScope.sessionUser.id
                # assume there were no photos in the workorder to change
                woDevices = workorderObj.get('devices')
                woDevices.push update.deviceId
                woUpdate['deviceId'] = update.deviceId
                woUpdate['devices'] = _.unique woDevices
                changed[oldDeviceId] = []
               
              return workorderObj.save(woUpdate).then (woObj)->
                    changed[oldDeviceId].push "workorder.id="+ woObj.id
                    # console.log "\n\n *** _PATCH_DeviceId Workorder changed, UUID=" + woObj.attributes.UUID
                    return changed
                  , (err)->
                    changed[oldDeviceId].push 'error: workorderObj'
                    console.warn "\n\n *** _PATCH_DeviceId, error: "+JSON.stringify err
                    return changed
            , (err)->
              console.warn "\n\n ERROR: _PATCH_DeviceId Workorder "
              console.warn err

          .then (resp)->
            isError = JSON.stringify( resp ).indexOf('error') != -1
            # console.log "\n >>> _PATCH_DeviceId_OneWorkorder_P(), resp=" + JSON.stringify resp
            return $q.reject(resp) if isError
            return $q.when( true )

            
      # connect to Settings > Advanced button
      _PATCH_DeviceIds_AllWorkorders_P : ()->
        onlyLocal = []
        return cameraRoll.mapP({},'replace')
        .then (mapped)->
          # only localPhotos, nothing from DB
          _.each mapped, (o)->
            o.from = 'CameraRoll'
          onlyLocal = _.clone mapped
          return self.fetchWorkordersP()
        .then (workorderColl)->
          promises = []
          workorderColl.each (workorderObj)->
            promises.push self._PATCH_DeviceId_OneWorkorder_P( onlyLocal, workorderObj  ) 
          return $q.all(promises)



      _PATCH_WorkorderAssets:(parsePhotosColl, patchKeys)->
        _alreadyPatched = {}
        PATCH_KEYS =  patchKeys  # ['originalWidth', 'originalHeight', 'date']
        parsePhotosColl.each ( phObj )->
          crPhoto = _.findWhere cameraRoll.map(), { UUID: phObj.get('UUID') }
          return if !crPhoto || crPhoto.from=='PARSE'
          return if _alreadyPatched[crPhoto.UUID]
          updateFromCameraRoll = _.pick crPhoto, PATCH_KEYS
          return if _.isEmpty updateFromCameraRoll 

          phObj.save( updateFromCameraRoll ).then ()->
              updateFromCameraRoll.UUID = crPhoto.UUID
              _alreadyPatched[crPhoto.UUID] = 1
              # console.log "\n\n *** _PATCH_WorkorderAssets, patched:" + JSON.stringify updateFromCameraRoll
            , (err)->
              console.warn "\n\n *** _PATCH_WorkorderAssets, error: "+JSON.stringify err
              return
        return

      # wrap in timeouts 
      SYNC_ORDERS : (scope, force, DELAY=10, whenDoneP)->
        return if !$rootScope.sessionUser
        # run AFTER cameraRoll loaded
        # return if _.isEmpty $rootScope.sessionUser
        # if deviceReady.device().isDevice && _.isEmpty cameraRoll.map()
        #   return whenDoneP() if whenDoneP

        options = {
          role: 'owner'
          owner: true
        }

        # PATCH_ParsePhotoObjKeys =  [
        #   'originalWidth', 'originalHeight', 
        #   'rating', 'favorite', 'caption', "hidden"
        #   'exif', 'orientation'
        #   "mediaType",  "mediaSubTypes", "burstIdentifier", "burstSelectionTypes", "representsBurst",
        # ] 
        PATCH_ParsePhotoObjKeys = false # ['originalWidth', 'originalHeight', 'date']

        if PATCH_ParsePhotoObjKeys
          imageCacheSvc.clearStashedP('preview') # force cameraRoll fetch


        $timeout ()->
            # console.log "\n\n*** BEGIN Workorder Sync for role=" + options.role + "\n"
            self.fetchWorkordersP( options , force ).then (workorderColl)->

                promises = []
                $rootScope.counts['orders'] = openOrders = 0
                isBrowser = !isDevice =  deviceReady.device().isDevice
                workorderColl.each (workorderObj)->

                  # isComplete = /^(complete|closed)/.test workorderObj.get('status')
                  # if scope.$state.includes('app.orders.complete')
                  #   return if !isComplete
                  # else 
                  #   return if isComplete
                  return if isDevice && workorderObj.get('devices').indexOf($rootScope.device.id) == -1 

                  openOrders++
                  p = self.fetchWorkorderPhotosP(workorderObj, options, force )
                  .then (photosColl)->

                    # see also: otgParse._patchParsePhotos()
                    if PATCH_ParsePhotoObjKeys
                      # save CameraRoll attrs to PARSE
                      self._PATCH_WorkorderAssets( photosColl , PATCH_ParsePhotoObjKeys)

                    return self.syncWorkorderPhotosP( workorderObj, photosColl, 'owner' )
                  .then (sync)->
                      # console.log "\n\n *** SYNC_ORDERS: woid=" + workorderObj.id
                      # console.log "sync=" + JSON.stringify sync
                      self.updateWorkorderCounts(workorderObj, sync)
                      return sync
                  .then (resp)->
                      # console.log "fetchWorkordersP done"
                      return 
                    , (err)->
                      console.warn(err) 
                      return $q.when(err)
                  promises.push p


                  $rootScope.counts['orders'] = openOrders || 0
                  return # end workorderColl.each

                $q.all( promises ).then (o)->
                  $rootScope.orders = scope.workorders = workorderColl.toJSON()
                  # console.log "\n\n*** ORDER SYNC complete for role=" + options.role + "\n"
                  $rootScope.$broadcast('sync.ordersComplete')
                  return whenDoneP(workorderColl) if whenDoneP


          , DELAY

      # wrap in timeouts 
      SYNC_WORKORDERS : (scope, force, DELAY=10, whenDoneP)->
        # run AFTER cameraRoll loaded
        return if _.isEmpty $rootScope.sessionUser
        return if deviceReady.device().isDevice && _.isEmpty cameraRoll.map()

        options = {
          role: 'editor'
          editor: true
          acl : true
          workorder: true
        }

        $timeout ()->
            # console.log "\n\n*** BEGIN Workorder Sync for role=" + options.role + "\n"
            self.fetchWorkordersP( options , force ).then (workorderColl)->

                promises = []
                openOrders = 0
                workorderColl.each (workorderObj)->
                  isComplete = /^(complete|closed)/.test workorderObj.get('status')

                  ## WARN: if we don't get photos for all workorders now
                  ##  then otgMoment.summarize() photos are not found in cameraRoll.map()
                  if false && 'skip'
                    if scope.$state.includes('app.workorders.open')
                      return if isComplete
                    if scope.$state.includes('app.workorders.complete')
                      return if !isComplete

                  openOrders++
                  photosColl = null
                  p = self.fetchWorkorderPhotosP(workorderObj, options, force )
                  .then (resp)->
                    photosColl = resp
                    # ???: is there a 'sync' for workorders, should be on browser...
                    # just need counts
                    return self.syncWorkorderPhotosP( workorderObj, photosColl, 'editor' )
                  .then (sync)->
                    self.updateWorkorderCounts(workorderObj, sync)  # expect workorderObj.workorderMoment to be set
                     
                    return photosColl

                  $rootScope.counts['orders'] = openOrders 
                  promises.push p
                  return

                $q.all( promises ).then (o)->
                  $rootScope.orders = scope.workorders = workorderColl.toJSON() 
                  # console.log "\n\n*** Workorder SYNC complete for role=" + options.role
                  $rootScope.$broadcast('sync.workordersComplete')
                  return whenDoneP(workorderColl) if whenDoneP
          , DELAY

      updateWorkorderCounts: (woObj, sync)->
        # sync: # see syncDateRange_Photos_P()
          # 'add': 
          # 'remove':
          # 'complete':
          # 'queued':
          # 'errors':
          # 'lastUploadDate':
        return console.warn "ERROR: updateWorkorderCounts, sync is null" if !sync?
        updates = {
          'count_received': sync['complete'].length
          'count_expected': sync['complete'].length + sync['queued'].length + sync['errors'].length
          'count_errors': sync['errors'].length
        }
        updates['lastUploadAt'] = sync['lastUploadDate'] if sync['lastUploadDate']
        return if _.isEmpty updates
        return woObj.save( updates ).then (resp)->
            angular.noop()
          , (err)->
            console.warn "updateWorkorderCounts() save error", err
    }
    return self

]

.factory 'otgParse', [
  '$q', '$ionicPlatform', '$timeout', '$rootScope', 'deviceReady', 'cameraRoll', 'PLUGIN_CAMERA_CONSTANTS'
  ($q, $ionicPlatform, $timeout, $rootScope, deviceReady, cameraRoll, CAMERA)->

    parseClass = {
      PhotoObj : Parse.Object.extend('PhotoObj',  {
          initialize: (attrs, options)->
            if options?.initClass == true
              console.log "\n\n\n >>>> PhotoObj initialize() attrs=\n" + JSON.stringify attrs
              ## force PhotoObj attributes with first upload by adding classDefaults
              classDefaults = {
                UUID: '' # char(36)
                deviceId: '' # char(36)
                owner: 'Parse pointer' # Pointer < Parse.User
                workorder: 'Parse pointer' # Pointer < WorkorderObj
                dateTaken : new Date().toJSON() # UTC time
                originalWidth : 0
                originalHeight : 0
                favorite : false # Boolean value from Photos framework
                # for mapping UIImageOrientation to Exif Orientation, see http://cloudintouch.it/2014/04/03/exif-pain-orientation-ios/
                exifOrientation : 1 # Exif Orientation Tag value, 
                ### from PHAsset: https://developer.apple.com/library/ios/documentation/Photos/Reference/PHAsset_Class/
                    @"mediaType":@(asset.mediaType),
                    @"mediaSubTypes":@(asset.mediaSubtypes),
                    @"hidden":@(asset.hidden),
                    @"favorite":@(asset.favorite),
                    @"originalWidth":@(asset.pixelWidth),
                    @"originalHeight":@(asset.pixelHeight),
                    @"burstIdentifier":@(asset.burstIdentifier),
                    @"burstSelectionTypes":@(asset.burstSelectionTypes),
                    @"representsBurst"@(asset.representsBurst)
                ### 
                exif: {} # Q: can you embed EXIF data in the uploaded JPG?  I can read it from the server.
                rating : 0
                topPick: false
                shared: false
                caption : ''
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
      BacklogObj : Parse.Object.extend('BacklogObj')
      
    }

    ANON_PREFIX = {
      username: 'anonymous-'
      password: 'password-'
    }

    ANON_USER = {
      id: null

      username: null
      password: null
      role: 'owner'
      email: null
      emailVerified: false

      tosAgree: false
      rememberMe: false
      isRegistered: false       
    }


    self = {
      isAnonymousUser: ()->
        return true if _.isEmpty $rootScope.sessionUser
        return true if $rootScope.sessionUser.get('username').indexOf(ANON_PREFIX.username) == 0
        # return true if $rootScope.sessionUser.get('username') == 'browser'
        return false

      mergeSessionUser: (anonUser={})->
        anonUser = _.extend _.clone(ANON_USER), anonUser
        # merge from cookie into $rootScope.user
        $rootScope.sessionUser = Parse.User.current()
        return anonUser if !($rootScope.sessionUser instanceof Parse.Object)

        isRegistered = !self.isAnonymousUser()
        return anonUser if !isRegistered
        
        userCred = _.pick( $rootScope.sessionUser.toJSON(), [
          'username', 'role', 
          'email', 'emailVerified', 
          'tosAgree', 'rememberMe'
        ] )
        userCred.password = 'HIDDEN'
        userCred.tosAgree = !!userCred.tosAgree # checkbox:ng-model expects a boolean
        userCred.isRegistered = true
        return _.extend anonUser, userCred




      signUpP: (userCred)->
        user = new Parse.User();
        user.set("username", userCred.username.toLowerCase())
        user.set("password", userCred.password)
        user.set("email", userCred.email) 
        return user.signUp().then (user)->
            return $rootScope.sessionUser = Parse.User.current()
          , (user, error)->
            $rootScope.sessionUser = null
            $rootScope.user.username = ''
            $rootScope.user.password = ''
            $rootScope.user.email = ''
            console.warn "parse User.signUp error, msg=" + JSON.stringify error
            return $q.reject(error)

      ###
      # @params userCred object, keys {username:, password:}
      #     or array of keys
      ###
      loginP: (userCred, signOutOnErr=true)->
        userCred = _.pick userCred, ['username', 'password']
        return deviceReady.waitP().then ()->
          return Parse.User.logIn( userCred.username.trim().toLowerCase(), userCred.password )
        .then (user)->  
            $rootScope.sessionUser = Parse.User.current()
            $rootScope.user.isRegistered = true
            $rootScope.user = self.mergeSessionUser($rootScope.user)
            return user
        , (error)->
            if signOutOnErr
              $rootScope.sessionUser = null
              $rootScope.$broadcast 'user:sign-out'
              console.warn "User login error. msg=" + JSON.stringify error
            $q.reject(error)


      logoutSession: (anonUser)->
        Parse.User.logOut()
        $rootScope.sessionUser = Parse.User.current()
        _.extend $rootScope.user , ANON_USER
        return

      anonSignUpP: (seed)->
        _uniqueId = (length=8) ->
          id = ""
          id += Math.random().toString(36).substr(2) while id.length < length
          id.substr 0, length
        seed = _uniqueId(8) if !seed
        anon = {
          username: ANON_PREFIX.username + seed
          password: ANON_PREFIX.password + seed
        }
        return self.signUpP(anon).then (userObj)->
              return userObj
            , (userCred, error)->
              console.warn "parseUser anonSignUpP() FAILED, userCred=" + JSON.stringify userCred 
              return $q.reject( error )

      # confirm userCred or create anonymous user if Parse.User.current()==null
      checkSessionUserP: (userCred, createAnonUser=true)-> 
        if !deviceReady.isOnline()
          return $q.reject("Error: Network unavailable") 

        if userCred # confirm userCred
          authPromise = self.loginP(userCred, false).then null, (err)->
              return $q.reject({
                  message: "userCred invalid"
                  code: 301
                })
        else if $rootScope.sessionUser
          authPromise = $q.when($rootScope.sessionUser)
        else 
          authPromise = $q.reject()

        if createAnonUser
          authPromise = authPromise.then (o)->
              return o
            , (error)->
              return self.anonSignUpP()

        return authPromise


      saveSessionUserP : (updateKeys, userCred)->
        # update or create
        if _.isEmpty($rootScope.sessionUser)
          # create
          promise = self.signUpP(userCred)
        else if self.isAnonymousUser()
          promise = $q.when()
        else  # verify userCred before updating user profile
          reverify = {
            username: userCred['username']
            password: userCred['currentPassword']
          }
          promise = self.checkSessionUserP(reverify, false)

        promise = promise.then ()->
            # userCred should be valid, continue with update
            _.each updateKeys, (key)->
                if key=='username'
                  userCred['username'] = userCred['username'].trim().toLowerCase()
                $rootScope.sessionUser.set(key, userCred[key])
                return
            return $rootScope.sessionUser.save().then ()->
                return $rootScope.user = self.mergeSessionUser($rootScope.user)
              , (error)->
                $rootScope.sessionUser = null
                $rootScope.user.username = ''
                $rootScope.user.password = ''
                $rootScope.user.email = ''
                console.warn "parse User.save error, msg=" + JSON.stringify error
                return $q.reject(error)
          .then ()->
              $rootScope.sessionUser = Parse.User.current()
              return $q.when($rootScope.sessionUser)
            , (err)->
              return $q.reject(err) # end of line

      checkSessionUserRoleP : (o)->
        # Placeholder: for workorders, check for role=EDITOR and Assignment
        o.role = 'EDITOR'
        return $q.when(o)

      updateUserProfileP : (options)->
        keys = ['tosAgree', 'rememberMe']
        options = _.pick options, keys
        return $q.when() if _.isEmpty options
        return deviceReady.waitP().then ()->
          return self.checkSessionUserP(null, true)
        .then ()->
            return $rootScope.sessionUser.save(options)
          , (err)->
            return err

      checkBacklogP: ()->
        return deviceReady.waitP()
        .then ()->
          query = new Parse.Query(parseClass.BacklogObj)
          return query.first()
          .then (backlog)->
            return backlog if backlog
            backlog = new parseClass.BacklogObj({
              status: 'new'
              orders: 0
              photos: 0
            })
            return backlog.save()


      findWorkorderP : (options)->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('owner', $rootScope.sessionUser)
        # # or query on relation
        # contributors = parseClass.workorderObj.getRelation('contributors')
        # contrib = new Parse.Query(contributors)
        query.equalTo('objectId', options.id) if options.id
        query.equalTo('status', options.status) if options.status
        query.equalTo('fromDate', options.dateRange.from) if options.dateRange
        query.equalTo('fromDate', options.fromDate) if options.fromDate
        query.equalTo('toDate', options.dateRange.to) if options.dateRange
        query.equalTo('toDate', options.toDate) if options.toDate
        return query.find()


      createWorkorderP : (checkout, servicePlan, status='new')->
        parseData = {
          owner: $rootScope.sessionUser
          deviceId: $rootScope.device.id
          # contributors: [$rootScope.sessionUser]
          # accessors: []
          fromDate: checkout.dateRange.from
          toDate: checkout.dateRange.to
          devices: [$rootScope.device.id]
          count_expected: checkout.count.photos || 0 
          count_received: 0
          count_duplicate: 0
          count_days: checkout.count.days 
          servicePlan: servicePlan
          editor: null 
          status: status
          startedAt: null
          finishedAt: null
          approvedAt: null
          lastActionAt: null
          elapsed: 0
          acl: null
        }

        workorderObj = new parseClass.WorkorderObj(parseData)
        workorderObj.relation('accessors').add($rootScope.sessionUser)
        workorderObj.relation('contributors').add($rootScope.sessionUser)

        # set default ACL, owner:rw, Curator:rw
        woACL = new Parse.ACL(owner)
        woACL.setRoleReadAccess('Curator', true)
        woACL.setRoleWriteAccess('Curator', true)
        workorderObj.setACL(woACL)
        return workorderObj.save().then null, (error)->
          console.error "parse WorkorderObj save error, msg=" + JSON.stringify error
          throw error

      _patchParsePhotos : (photosColl)->
        # add/update Parse photos to cameraRoll
        changed = false
        photosColl.each (photoObj)->
          # cameraRoll.patchPhoto(): will just patch local attrs
          # photoObj.set('UUID', photoObj.get('assetId') ) # DEPRECATE, use UUID on PARSE
          # photoObj.set('date', cameraRoll.getDateFromLocalTime( photoObj.get('dateTaken') ) )
          # photoObj.set('from', 'PARSE' )
          photo = photoObj.toJSON()
          photo.date = cameraRoll.getDateFromLocalTime(photo.dateTaken)
          photo.from = "PARSE"
          photo.topPick = null if `photo.topPick==null` 
          # if photo.topPick
          #   console.log "%%% _patchParsePhotos topPick found!!! photo=" + JSON.stringify photo
          try 
            updated = cameraRoll.addOrUpdatePhoto_FromWorkorder photo
          catch 
            'not patched'
          changed = changed || updated
          return
        $rootScope.$broadcast 'sync.cameraRollChanged'
        return 



      fetchWorkordersByOwnerP : (options={})->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('owner', $rootScope.sessionUser)
        if options.editor
          options.editor = $rootScope.sessionUser if options.editor == true
          # console.warn "\n\n ***  WARNING: using workorder.owner as a proxy for workorder.editor for the moment\n"
          query.equalTo('owner', options.editor) 
        collection = query.collection()
        collection.comparator = (o)->
          return o.get('toDate')
        return collection.fetch()

      fetchWorkordersByACLP : (options={})->
        query = new Parse.Query(parseClass.WorkorderObj)
        if false && 'use query.include()'
          # query.include('owner') # does not work with collections
          # query.addDescending('createdAt')
          # return query.find()
        else 
          query.addDescending('createdAt')
          collection = query.collection()
          # collection.comparator = (o)->
          #   return o.get('toDate')
          return collection.fetch()


      getWorkorderByIdP : (woid)->
        query = new Parse.Query(parseClass.WorkorderObj)
        query.equalTo('objectId', woid)
        return query.first()  

      updateWorkorderP: (woObj, data, pick)->
        return $q.reject('updateWorkorderP: workorderObj not found ') if !woObj
        update = _.pick data, pick
        return $q.reject('updateWorkorderP: nothing to update') if _.isEmpty update
        return woObj.save(update) 

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
        query.notEqualTo('remove', true)
        if options.acl
          angular.noop()
        else 
          if options.owner
            query.equalTo('owner', $rootScope.sessionUser) 
          else if options.editor
            options.editor = $rootScope.sessionUser if options.editor == true
            # console.warn "\n\n ***  WARNING: using workorder.owner as a proxy for workorder.editor for the moment\n"
            query.equalTo('owner', options.editor) 

        query.limit(1000)  # parse limit, use query.skip() to continue
        collection = query.collection()
        # collection.comparator = (o)->
        #   return o.get('toDate')
        return collection.fetch().then (photosColl)->
            try
              self._patchParsePhotos(photosColl)
            catch e

            return photosColl
          , (err)->
            return $q.reject(err)
          
      setFavoriteP: (photo)->
        return $q.reject() if `photo.favorite==null`
        return cameraRoll.setFavoriteP(photo)
        .catch (err)->
          console.warn 'ERROR: saving Favorite to CameraRoll'
          return $q.reject(err)
        .then ()->
          return self.updatePhotoP(photo, 'favorite')
        .catch (err)->
          switch err
            when 'not found'
              # cameraRoll photo, not in Parse
              return photo
            else 
              console.warn 'ERROR: saving Favorite to Parse'
              return $q.reject(err)



      savePhotoP : (item, collection, pick)->
        photoObj = _.findWhere(collection.models, {id: item.objectId})
        return $q.reject('savePhotoP photo not found') if !photoObj
        data = _.pick item, pick
        photoObj.set(data)
        return photoObj.save()

      updatePhotoP: (photo, pick, isDevice=true)->
        # find photoObj   
        update = _.pick photo, pick
        query = new Parse.Query( parseClass.PhotoObj )
        query.equalTo 'UUID', photo.UUID
        if isDevice || $rootScope.user.role == 'owner'
          query.equalTo('owner', $rootScope.sessionUser) 
          query.equalTo('deviceId', $rootScope.device.id) 
        return query.find().then (photos)->
          return $q.reject("not found") if _.isEmpty photos,
          promises = []
          _.each photos, (photoObj)->
              p = photoObj.save(update).then (phObj)->
                # console.log "\n\n ### PARSE: photoObj saved, attrs=" + JSON.stringify _.pick photoObj.toJSON(), ['UUID', 'src']
                return photoObj
              promises.push p 
          return $q.all(promises).then (o)->
            if o.length > 1
              update.count = o.length
              # console.log "\n\n ### PARSE: ALL photoObj saved, resp=" + JSON.stringify update
            return $q.when(o)


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
        
      # 'parse' uploader only, requires DataURLs
      uploadFileP : (base64src, photo)->
        if /^data:image/.test(base64src)
          # expecting this prefix: 'data:image/jpg;base64,' + rawBase64
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
  

      uploadPhotoMetaP: (workorderObj, photo)->
        return $q.reject("uploadPhotoMetaP: photo is empty") if !photo
        # upload photo meta BEFORE file upload from native uploader
        # photo.src == 'queued'
        return deviceReady.waitP().then self.checkSessionUserP(null, false)
        .then ()-> 
          attrsForParse = [
            'dateTaken', 'originalWidth', 'originalHeight', 
            'rating', 'favorite', 'caption', "hidden"
            'exif', 'orientation'
            "mediaType",  "mediaSubTypes", "burstIdentifier", "burstSelectionTypes", "representsBurst",
          ]
          extendedAttrs = _.pick photo, attrsForParse
          # console.log extendedAttrs

          parseData = _.extend {
                # assetId: photo.UUID  # deprecate
                UUID: photo.UUID
                owner: $rootScope.sessionUser
                workorder : workorderObj
                deviceId: $rootScope.device.id
                src: "queued"
            }
            , extendedAttrs # , classDefaults

          photoObj = new parseClass.PhotoObj parseData , {initClass: false }
          # set default ACL, owner:rw, Curator:rw
          photoACL = new Parse.ACL(parseData.owner)
          photoACL.setRoleReadAccess('Curator', true)
          photoACL.setRoleWriteAccess('Curator', true)
          photoObj.setACL (photoACL)
          return photoObj.save()
        .then (o)->
            # console.log "photoObj.save() complete: " + JSON.stringify o.attributes 
            return 
          , (err)->
            console.warn "ERROR: uploadPhotoMetaP photoObj.save(), err=" + JSON.stringify err
            return $q.reject(err)

      uploadPhotoFileP : (UUID, size)->
        # called by parseUploader, _uploadNext()
        # upload file then update PhotoObj photo.src, does not know workorder
        # return parseFile = { UUID:, url(): }
        UPLOAD_IMAGE_SIZE = size || 'preview'
        return deviceReady.waitP().then self.checkSessionUserP(null, false) 
          .then ()->
            if deviceReady.device().isBrowser
              return $q.reject( {
                UUID: UUID
                message: "error: file upload not available from browser"
              }) 
          .then ()->
            # fetch with promise
            # TODO: need to set options.DestinationType = CAMERA.DestinationType.DATA_URL
            options = {
              size: UPLOAD_IMAGE_SIZE
              noCache: true
              DestinationType: CAMERA.DestinationType.DATA_URL
            }
            return cameraRoll.getPhoto_P( UUID, options)
            .catch (error)->
              error = error.shift() if _.isArray(error)
              if error.message == "Base64 encoding failed"
                error.message == "error: Base64 encoding failed"
              if error.message = "Not found!"
                error.message = "error: UUID not found in CameraRoll"
              $q.reject(error)
          .then (photo)->
            # photo.UUID, photo.data = dataURL
            return self.uploadFileP(photo.data, photo)
          .catch (error)->
            skipErrorFile = {
              UUID: error.UUID
              url: ()-> return error.message
            }
            switch error.message
              when "error: Base64 encoding failed", "Base64 encoding failed"
                return $q.when skipErrorFile
              when "error: UUID not found in CameraRoll", "Not found!"
                return $q.when skipErrorFile
              else 
                throw error      

    }
    return self
]


# # test cloudCode with js debugger
window.cloud = { 
}



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
