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
      dirty: false
      regExp : /^[a-z0-9_!\@\#\$\%\^\&\*.-]{3,20}$/
      isChanged: (ev)->
        return self.dirty = _username.dirty = true
      isValid: (ev)->
        return _username.regExp.test($rootScope.user.username.toLowerCase())
      ngClassValidIcon: ()->
        return 'hide' if !_username.dirty || !$rootScope.user.username
        if _username.isValid($rootScope.user.username.toLowerCase())
          # TODO: also check with parse?
          return 'ion-ios-checkmark balanced' 
        else 
          return 'ion-ios-close assertive'
    }

    _password = {
      dirty: false
      regExp : /^[A-Za-z0-9_-]{8,20}$/
      passwordAgainModel: null
      showPasswordAgain : ''
      edit: (ev)-> 
        # show password confirm popup before edit
        self.dirty = _password.dirty = true
        _password.showPasswordAgain = true
        $rootScope.user.password = ''
      isChanged: (ev)->
        return self.dirty = _password.dirty = true

      isValid: (ev)-> # validate password
        return _password.regExp.test($rootScope.user.password)

      isConfirmed: ()-> 
        return _password.isValid() && _password.passwordAgainModel == $rootScope.user.password
      
      ngClassValidIcon: ()->
        return 'hide' if !_password.dirty
        if _password.isValid($rootScope.user.password)
          return 'ion-ios-checkmark balanced' 
        else 
          return 'ion-ios-close assertive'
      ngClassConfirmedIcon: ()->
        return 'hide' if !_password.dirty || !_password.passwordAgainModel
        if _password.isConfirmed() 
          return 'ion-ios-checkmark balanced' 
        else 
          return 'ion-ios-close assertive'
    }

    _email = {
      changing: false
      dirty: false
      
      regExp : /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
      isChanged: (ev)->
        return self.dirty = _email.dirty = true
      isValid: (ev)->
        return _email.regExp.test($rootScope.user.email)
      isVerified: ()->
        return $rootScope.user.emailVerified
      ngClassEmailIcon: ()->
        if _email.dirty 
          if _email.isValid()
            return 'ion-ios-checkmark balanced' 
          else 
            return 'ion-ios-close assertive'
        else 
          if _email.isVerified()
            return 'ion-ios-checkmark balanced'
          else if $rootScope.user.email?
            return 'ion-flag assertive'
          else 
            return 'hide'

    }

    self = {
      isAnonymous: otgParse.isAnonymousUser
      signInP: (ev)->
        
        return otgParse.loginP(['username', 'password']).then (o)->
            self.dirty = _username.dirty = _password.dirty = _email.dirty = false
            # $state.transitionTo('app.settings.profile')
            return o
          , (err)->
            self.dirty = _username.dirty = _password.dirty = _email.dirty = false
            $rootScope.user.password = ''
            $q.reject(err)

      submitP: ()->
        updateKeys = []
        _.each ['username', 'password', 'email'], (key)->
          updateKeys.push(key) if self[key].dirty
          # if key == 'email'  # managed by parse
          #   $rootScope.user['emailVerified'] = false
          #   updateKeys.push('emailVerified')
          return
        return otgParse.saveSessionUserP(updateKeys).finally ()->
          self.dirty = _username.dirty = _password.dirty = _email.dirty = false
          return $q.when()

      ngClassSubmit : ()->
        if self.dirty && 
        _email.isValid($rootScope.user.email) &&
        (!_password.dirty || (_password.dirty && _password.isConfirmed()) )
          enabled = true 
        else 
          enabled = false
        return if enabled then 'button-balanced' else 'button-energized disabled'

      ngClassSignin : ()->
        if self.dirty && _password.dirty && _username.dirty
          enabled = true 
        else 
          enabled = false
        return if enabled then 'button-balanced' else 'button-energized disabled'



      displaySessionUsername: ()->
        return "anonymous" if self.isAnonymous()
        return $rootScope.sessionUser.get('username')

      signOut: ()->
        otgParse.logoutSession()
        return 

      username: _username
      password: _password
      email: _email
      errorMessage: ''
      dirty: false
    }
    
    return self

]
.controller 'SettingsCtrl', [
  '$scope', '$rootScope', '$state','$timeout', 
  '$ionicHistory', '$ionicPopup', '$ionicNavBarDelegate', 
  'otgParse', 'otgProfile', 'otgWorkorderSync', 'otgUploader', 'imageCacheSvc', 'cameraRoll'
  ($scope, $rootScope, $state, $timeout, $ionicHistory, $ionicPopup, $ionicNavBarDelegate, otgParse, otgProfile, otgWorkorderSync, otgUploader, imageCacheSvc, cameraRoll) ->
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
      clearCache: ()->
        $scope.watch.isWorking.clearAppCache = true
        cameraRoll.dataURLs['thumbnail'] = {}
        cameraRoll.dataURLs['preview'] = {}
        imageCacheSvc.clearStashedP(null, null, 'appCache').then ()->
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

    }

    $scope.signOut = (ev)->
      ev.preventDefault()    
      otgProfile.signOut()
      _.extend $scope.user, $rootScope.user
      otgWorkorderSync.clear()
      otgUploader.uploader.clearQueueP()
      $rootScope.$broadcast 'user:sign-out' 
      $state.transitionTo('app.settings.sign-in')
      return     
    
    $scope.signIn = (ev)->
      ev.preventDefault()
      return if otgProfile.ngClassSignin().indexOf('disabled') > -1
      
      otgWorkorderSync.clear()
      $rootScope.user = _.pick $scope.user, ['username', 'password']
      return otgProfile.signInP().then ()->
          otgProfile.errorMessage = ''
          target = 'app.settings.main'
          target = 'app.workorders.open' if /workorders/.test($scope.SideMenuSwitcher?.leftSide.src)
          $ionicHistory.nextViewOptions({
            historyRoot: true
          })

          $state.transitionTo(target)  

        , (error)->
          _.extend $scope.user, $rootScope.user
          $scope.user.password == ''
          otgProfile.username.dirty = !! $scope.user.username
          $state.transitionTo('app.settings.sign-in')
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




    $scope.submit = (ev)->
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
          $state.transitionTo(target)
        # else stay on app.settings.profile page
      .catch (error)->
        _.extend $scope.user, $rootScope.user
        otgProfile.password.passwordAgainModel = ''
        switch error.code 
          when 202
            message = i18n.tr('error-codes','app.settings')[error.code] # "That Username was already taken. Please try again."
          when 203
            message = i18n.tr('error-codes','app.settings')[error.code] # "That Email address was already taken. Please try again."
          else
            message = i18n.tr('error-codes','app.settings')[11] # "Sign-up unsucessful. Please try again."
        $scope.otgProfile.errorMessage = message
        return 
      return 


    $scope.$on '$ionicView.loaded', ()->
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      _.extend $scope.watch.imgCache, imageCacheSvc.stashStats()
      _.extend $scope.user, $rootScope.user
      otgProfile.errorMessage = ''
      return

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 

]  