'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:SettingsCtrl
 # @description
 # # SettingsCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.factory 'otgProfile', [
  '$rootScope', '$q', 'otgParse'
  ($rootScope, $q, otgParse)->

    _username = {
      regExp : /^[a-z0-9_!\@\#\$\%\^\&\*.-]{3,20}$/

      dirty : ()->
        return $rootScope.user['username'] != self.userModel()['username']

      isValid: (ev)->
        return self.userModel()['username']? && _username.regExp.test(self.userModel()['username'].toLowerCase())

      ngClassValidIcon: ()->
        return 'hide' if !_username.dirty() || !self.userModel()['username']
        if _username.isValid(self.userModel()['username'].toLowerCase())
          # TODO: also check with parse?
          return 'ion-ios-checkmark balanced' 
        else 
          return 'ion-ios-close assertive'
    }

    _password = {
      regExp : /^[A-Za-z0-9_-]{8,20}$/
      'passwordAgainModel': null
      showPasswordAgain : ''

      dirty : ()->
        return $rootScope.user['password'] != self.userModel()['password']

      edit: ()-> 
        # show password confirm popup before edit
        _password.showPasswordAgain = true
        self.userModel()['password'] = ''

      isValid: (field='password')-> # validate password or oldPassword
        return self.userModel()[field]? && _password.regExp.test(self.userModel()[field])

      isConfirmed: ()-> 
        return _password.isValid() && _password['passwordAgainModel'] == self.userModel()['password']
      
      ngClassValidIcon: (field='password')->
        return 'hide' if !_password.dirty()
        if _password.isValid(field)
          return 'ion-ios-checkmark balanced' 
        else 
          return 'ion-ios-close assertive'
      ngClassConfirmedIcon: ()->
        return 'hide' if !_password.dirty() || !_password['passwordAgainModel']
        if _password.isConfirmed() 
          return 'ion-ios-checkmark balanced' 
        else 
          return 'ion-ios-close assertive'
    }

    _email = {
      dirty : ()->
        return $rootScope.user['email'] != self.userModel()['email']
      
      regExp : /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/

      isValid: (ev)->
        return self.userModel()['email']? && _email.regExp.test(self.userModel()['email'])
      isVerified: ()->
        return self.userModel()['emailVerified']
      ngClassEmailIcon: ()->
        if _email.dirty() 
          if _email.isValid()
            return 'ion-ios-checkmark balanced' 
          else 
            return 'ion-ios-close assertive'
        else 
          if _email.isVerified()
            return 'ion-ios-checkmark balanced'
          else if self.userModel()['email']?
            return 'ion-flag assertive'
          else 
            return 'hide'

    }

    self = {
      isAnonymous: otgParse.isAnonymousUser

      _userModel : {}
      userModel: (user)->
        return self._userModel if `user==null`
        return self._userModel = user

      dirty : ()->
        keys = ['username', 'password', 'email']
        return _.isEqual( _.pick( $rootScope.user, keys ),  _.pick( self.userModel(), keys )) == false

      signInP: (userCred)->
        return otgParse.loginP(userCred).then (o)->
            self.userModel( _.pick $rootScope.user, ['username', 'password', 'email', 'emailVerified'] )
            # $rootScope.$state.transitionTo('app.settings.profile')
            return o
          , (err)->
            self.userModel( {} )
            $q.reject(err)

      submitP: ()->
        updateKeys = []
        _.each ['username', 'password', 'email'], (key)->
          updateKeys.push(key) if self[key].dirty()           # if key == 'email'  # managed by parse
          return
        if !self.isAnonymous()
          # confirm current password before change
          updateKeys.push('currentPassword')
        return otgParse.saveSessionUserP(updateKeys, self.userModel() ).then (userObj)->
            self.userModel( _.pick $rootScope.user, ['username', 'password', 'email', 'emailVerified'] )
            return userObj

      ngClassSubmit : ()->
        if (self.email.dirty() && self.email.isValid()) || (self.password.dirty() && self.password.isConfirmed() )
          enabled = true 
        else 
          enabled = false
        return if enabled then 'button-balanced' else 'button-energized disabled'

      ngClassSignin : ()->
        if self.userModel()['username'] && self.userModel()['password']           
          enabled = true 
        else 
          enabled = false
        return if enabled then 'button-balanced' else 'button-energized disabled'



      displaySessionUsername: ()->
        return "anonymous" if self.isAnonymous()
        return $rootScope.sessionUser.get('username')

      signOut: ()->
        otgParse.logoutSession()
        self.userModel( {} )
        return 

      username: _username
      password: _password
      email: _email
      errorMessage: ''

    }
    
    return self

]
.controller 'SettingsCtrl', [
  '$scope', '$rootScope', '$timeout'
  '$ionicHistory', '$ionicPopup', '$ionicNavBarDelegate', 
  'otgParse', 'otgProfile', 'otgWorkorderSync', 'otgUploader', 
  'imageCacheSvc', 'cameraRoll', 'otgLocalStorage'
  ($scope, $rootScope, $timeout, $ionicHistory, $ionicPopup, $ionicNavBarDelegate, otgParse, otgProfile, otgWorkorderSync, otgUploader, imageCacheSvc, cameraRoll, otgLocalStorage) ->
    $scope.label = {
      title: "Settings"
    }
    
    $scope.otgProfile = otgProfile

    $scope.watch = {
      showAdvanced: false 
      isWorking:
        clearAppCache: false
        clearArchive: false
        resetDeviceId: false
      archive: 
        size: '0 Bytes'
        count: 0        
      imgCache: 
        size: '0 Bytes'
        count: 0
    }
    $scope.on = {
      showSpinnerWhenIframeLoading: (name)->
        $scope.watch.iframeOpened = $scope.watch.iframeOpened || {}
        return if $scope.watch.iframeOpened[name]?
        $scope.showLoading(true, 3000)
        $scope.watch.iframeOpened[name] = 1
      clearCacheP: ()->
        $scope.watch.isWorking.clearAppCache = true
        cameraRoll.dataURLs['thumbnail'] = {}
        cameraRoll.dataURLs['preview'] = {}
        return imageCacheSvc.clearStashedP(null, null, 'appCache').then ()->
          _.extend $scope.watch.imgCache, imageCacheSvc.stashStats('appCache')
          $scope.watch.isWorking.clearAppCache = false
      clearArchive: ()->
        return  # not yet implemented in localStorage, need to add new folder
        $scope.watch.isWorking.clearArchive = true
        imageCacheSvc.clearStashedP(null, null, 'archive').then ()->
          _.extend $scope.watch.archive, imageCacheSvc.stashStats('archive')
          $scope.watch.isWorking.clearArchive = false
      toggleShowAdvanced: ()->
        $scope.watch.showAdvanced = !$scope.watch.showAdvanced

      resetLocalStorage: ()->
        # copied from app.coffee: _RESTORE_FROM_LOCALSTORAGE() 
        isDevice = $scope.deviceReady.device().isDevice
        otgLocalStorage.loadDefaults([
          'config', 'menuCounts'
          'topPicks'
          'cameraRoll'
        ]) 
        return $scope.on.clearCacheP().then ()->
          if isDevice
            msg = "You MUST close and re-launch this App!"
            window.alert(msg)
          else 
            window.location.reload()
          return

      resetDeviceId: ()->
        return if $scope.deviceReady.device().isBrowser
        msg = "Are you sure you want to\nreset your DevideId?"
        resp = window.confirm(msg)
        if resp 
          $scope.watch.isWorking.resetDeviceId = true
          $timeout ()->
            otgWorkorderSync._PATCH_DeviceIds_AllWorkorders_P()
            .then ()-> 
              $scope.watch.isWorking.resetDeviceId = false
        return

      signOut : (ev)->
        ev.preventDefault() 
        # add confirm.
        if otgProfile.isAnonymous() && $rootScope.user.tosAgree
          msg = "Are you sure you want to sign-out?\nYou do not have a password and cannot recover this account"
          resp = window.confirm(msg)
          return false if !resp 
        otgProfile.signOut()
        otgWorkorderSync.clear()
        otgUploader.uploader.clearQueueP()
        $rootScope.$broadcast 'user:sign-out' 
        $rootScope.$state.transitionTo('app.settings.sign-in')
        return     
    
      signIn : (ev)->
        ev.preventDefault()
        return if otgProfile.ngClassSignin().indexOf('disabled') > -1
        
        otgWorkorderSync.clear()
        userCred = _.pick otgProfile.userModel(), ['username', 'password']
        return otgProfile.signInP(userCred).then ()->
            otgProfile.errorMessage = ''
            target = 'app.settings.main'
            target = 'app.workorders.open' if /workorders/.test($scope.SideMenuSwitcher?.leftSide.src)
            $ionicHistory.nextViewOptions({
              historyRoot: true
            })

            $rootScope.$state.transitionTo(target)  

          , (error)->
            otgProfile.userModel( {} )
            $rootScope.$state.transitionTo('app.settings.sign-in')
            switch error.code 
              when 101
                message = i18n.tr('error-codes','app.settings')[error.code] # "The Username and Password combination was not found. Please try again."
              else
                message = i18n.tr('error-codes','app.settings')[10] # "Sign-in unsucessful. Please try again."
            otgProfile.errorMessage = message
            return 
          .then ()->
            # refresh everything, including topPicks
            otgWorkorderSync.clear()
            cameraRoll.clearPhotos_PARSE()  
            if $scope.deviceReady.device().isBrowser            
              cameraRoll.clearPhotos_CameraRoll()           
            if otgParse.isAnonymousUser() == false
              window.TEST_DATA = null 
            $rootScope.$broadcast 'sync.cameraRollComplete'
            return


      submit : (ev)->
        ev.preventDefault()
        return if otgProfile.ngClassSubmit().indexOf('disabled') > -1

        # either update or CREATE
        isCreate = if _.isEmpty($rootScope.sessionUser) then true else false
        return otgProfile.submitP()
        .then ()->
            otgProfile.errorMessage = ''
            if isCreate
              $ionicHistory.nextViewOptions({
                historyRoot: true
              })
              target = 'app.settings.main'
              $rootScope.$state.transitionTo(target)
            # else stay on app.settings.profile page
        , (error)->
          otgProfile.password.passwordAgainModel = ''
          switch error.code 
            when 202, 203
              message = i18n.tr('error-codes','app.settings')[error.code] # "That Username/Email was already taken. Please try again."
            when 301
              otgProfile.userModel _.pick $rootScope.user, ['username', 'password', 'email', 'emailVerified']
              message = i18n.tr('error-codes','app.settings')[error.code] # no permission to make changes
            else
              message = i18n.tr('error-codes','app.settings')[11] # "Sign-up unsucessful. Please try again."
          otgProfile.errorMessage = message
          return 
        return 
    }

    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams)->
      return if /^app.settings/.test(toState.name) == false
      switch toState.name
        when 'app.settings.profile'
          otgProfile.userModel _.pick $rootScope.user, ['username', 'password', 'email', 'emailVerified']
        when 'app.settings.sign-in'
          otgProfile.userModel _.pick $rootScope.user, ['username', 'password']
      return
 


    $scope.$on '$ionicView.loaded', ()->
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      _.extend $scope.watch.imgCache, imageCacheSvc.stashStats()
      otgProfile.userModel _.pick $rootScope.user, ['username', 'password', 'email', 'emailVerified']
      otgProfile.errorMessage = ''
      return

    $scope.$on '$ionicView.enter', ()->
      angular.noop()


    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 

]  