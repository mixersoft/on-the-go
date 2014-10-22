'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:SettingsCtrl
 # @description
 # # SettingsCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.controller 'SettingsCtrl', [
  '$scope', '$ionicNavBarDelegate'
  ($scope, $ionicNavBarDelegate) ->
    $scope.label = {
      title: "Settings"
      subtitle: "Share something great today!"
    }

    $scope.password = password = {
      minLength: 3
      changing: !$scope.user.username
      passwordAgain: null
      old: null
      change: (ev)->
        return password.revert(ev) if password.changing
        console.log "click: "+ev.target
        password.changing = true
        password.old = $scope.user.password
        $scope.user.password = null
      revert: (ev)->
        return if password.changing == false
        $scope.user.password = password.old
        password.old = password.passwordAgain = null 
        password.changing = false
        ev.target.blur()
      commit: (ev)->
        if password.isValid() && password.isConfirmed()
          password.changing = false
          password.passwordAgain = null
          ev.target.blur()
        else return false
      isValid: ()->
        return $scope.user.password?.length >= password.minLength
      isConfirmed: ()-> 
        return password.isValid() && password.passwordAgain == $scope.user.password    
    }

    $scope.email = email = {
      changing: false
      old: null
      oldVerified: null
      change: (ev)->
        return email.revert(ev) if email.changing
        email.changing = true
        email.old = $scope.user.email
        email.oldVerified = $scope.user.emailVerified
        $scope.user.email = null
        $scope.user.emailVerified = false
      revert: (ev)->
        return if email.changing == false
        $scope.user.email = email.old
        $scope.user.emailVerified = email.oldVerified
        email.old = email.oldVerified = null 
        email.changing = false
        ev.target.blur()
      commit: (ev)->
        if email.isValid()
          email.changing = false
        else return false
      isValid: ()->
        return $scope.user.email?.length
      isVerified: ()->
        return $scope.user.emailVerified
    }




    init = ()->
      $scope.isAnonymous = !$scope.user.username
      return

    init()
]  