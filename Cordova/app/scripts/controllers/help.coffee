'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:HelpCtrl
 # @description
 # # HelpCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.controller 'HelpCtrl', ($scope) ->
  $scope.label = {
    title: "Help"
  }

    # open link externally
  $scope.GotoLink = (link)->
    # window.open(link,'_system');  # doesn't work
    return
  
