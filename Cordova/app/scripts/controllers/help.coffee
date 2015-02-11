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
    title: "Resources"
  }

  $scope.watch = {
  	links:
  		'on-the-go': 'http://app.snaphappi.com/on-the-go/'
  		facebook: 'http://www.facebook.com/Snaphappi'
  		twitter: 'https://twitter.com/snaphappi'
  		tumblr: 'http://tumblr.snaphappi.com/post/87220736621/on-the-go-curated-family-photos-re-mixed-for-mobile'
  		giving: "http://icangowithout.com/"
  }



    # open link externally
  $scope.on = {
  	openHref : ($ev, dest)->
	  	target = $ev.currentTarget
	  	dest = dest || target.href
	  	if $scope.deviceReady.device().isDevice
	  		window.open(dest,'_system', 'location=yes');  # doesn't work
	  		return false
	  	else if target.tagName != 'A'
	  		window.open(dest,'_blank', 'location=yes');
	  	else 
	    	return true

	}
  
