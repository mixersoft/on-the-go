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
        return _username.regExp.test($rootScope.user.username)
      ngClassValidIcon: ()->
        return 'hide' if !_username.dirty
        if _username.isValid($rootScope.user.username)
          return 'ion-ios7-checkmark balanced' 
        else 
          return 'ion-ios7-close assertive'
    }

    _password = {
      dirty: false
      regExp : /^[A-Za-z0-9_-]{3,20}$/
      passwordAgainModel: null
      showPasswordAgain : ''
      change: (ev)-> 
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
          return 'ion-ios7-checkmark balanced' 
        else 
          return 'ion-ios7-close assertive'
      ngClassConfirmedIcon: ()->
        return 'hide' if !_password.dirty || !_password.passwordAgainModel
        if _password.isConfirmed() 
          return 'ion-ios7-checkmark balanced' 
        else 
          return 'ion-ios7-close assertive'
    }

    _email = {
      changing: false
      dirty: false
      old: null
      oldVerified: null
      
      regExp : /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
      isChanged: (ev)->
        return self.dirty = _email.dirty = true
      isValid: (emailAddr)->
        return _email.regExp.test(emailAddr)
      isVerified: ()->
        return $rootScope.user.emailVerified
      ngClassEmailIcon: ()->
        if _email.dirty 
          if _email.isValid($rootScope.user.email)
            return 'ion-ios7-checkmark balanced' 
          else 
            return 'ion-ios7-close assertive'
        else 
          if _email.isVerified()
            return 'ion-ios7-checkmark balanced'
          else 
            return 'ion-flag assertive'

    }

    self = {
      isAnonymous: otgParse.isAnonymousUser
      submitP: ()->
        updateKeys = []
        _.each ['username', 'password', 'email'], (key)->
          updateKeys.push(key) if self[key].dirty
          # if key == 'email'  # managed by parse
          #   $rootScope.user['emailVerified'] = false
          #   updateKeys.push('emailVerified')
          return
        return otgParse.saveSessionUserP(updateKeys).then ()->
        # return otgParse.checkSessionUserP().then ()->
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
      username: _username
      password: _password
      email: _email
      dirty: false
    }
    
    return self

]
.controller 'SettingsCtrl', [
  '$scope', '$ionicNavBarDelegate', 'otgParse', 'otgProfile'
  ($scope, $ionicNavBarDelegate, otgParse, otgProfile) ->
    $scope.label = {
      title: "Settings"
      subtitle: "Share something great today!"
    }

    
    $scope.otgProfile = otgProfile
    

    init = ()->
      otgParse.checkSessionUserP().then (userCred)->
        return 
      return

    init()
]  