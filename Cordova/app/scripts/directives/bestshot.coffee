'use strict'

###*
 # @ngdoc directive
 # @name onTheGoApp.service:bestshot
 # @description
 # # bestshot
###
angular.module('onTheGoApp')
.factory('onTheGo.bestshot', ->
  template: '<div></div>'
  restrict: 'E'
  link: (scope, element, attrs) ->
    element.text 'this is the bestshot directive'
)
