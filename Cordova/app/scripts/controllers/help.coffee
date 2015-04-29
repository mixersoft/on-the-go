'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:HelpCtrl
 # @description
 # # HelpCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.controller 'HelpCtrl', [
  '$scope', 
  '$ionicPopup', 
  '$cordovaSocialSharing', 
  'otgParse'
  'notifyService'
($scope, $ionicPopup, $cordovaSocialSharing, otgParse, notifyService) ->
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
    device: $scope.deviceReady.device()
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
    helpMe : (event)->
      event.preventDefault()
      event.stopPropagation()
      return $scope.deviceReady.waitP().then (device)->
        imOK = true
        imOK = false if device.isBrowser
        imOK = false if device.platform?.platform != "iOS"

        if imOK == false
          confirmPopup = $ionicPopup.alert {
            title: "iMessage Not Available"
            template: "Sorry, iMessage Snaphappi is only available from an iPhone."
          }
          confirmPopup.then (res)->
          return  

        return otgParse.checkBacklogP()
      .then (backlog)-> 

        ### .shareViaSMS(
          'My cool message', 
          '0612345678', 
          function(msg) {console.log('ok: ' + msg)}, 
          function(msg) {alert('error: ' + msg)})
        ###
      
        # return $scope.on.socialShare()
        options = {
          message: 'Help! '
          number: backlog.get('iMessage')
        }
        if _.isEmpty options.number
          confirmPopup = $ionicPopup.alert {
            title: "iMessage Not Available"
            template: "Sorry, iMessage Snaphappi is not available right now."
          }
          confirmPopup.then (res)->
          return
        $cordovaSocialSharing
          # .shareViaFacebook(options.message, options.image, options.link)
          .shareViaSMS(options.message, options.number)
          .then (result)->
              msg = {
                title: "iMessage Snaphappi"
                message: "Your message was sent. We'll respond as soon as we can."
              }
              notifyService.message( msg, 'info', 5000)
              console.log "\n\n*** Success socialSharing check for cancel, SocialPlugin.shareViaSMS result"
              console.log result
            , (error)->
              cancelled = error == false
              return console.log "\n*** socialSharing CANCELLED"  if cancelled
              msg = {
                title: "iMessage Snaphappi"
                message: "There was a problem sending your message. Please contact us online."
              }
              notifyService.message(msg, 'warning', 5000)
              console.log "\n*** ERROR socialSharing:" , error  

  }
]
  
