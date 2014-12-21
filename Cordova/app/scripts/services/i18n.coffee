'use strict'

###*
 # @ngdoc service
 # @name ionBlankApp.i18n
 # @description
 # # i18n
 # String substitution with server override
###
angular.module('onTheGo.i18n', [])
.factory 'i18n', [ '$rootScope', ($rootScope)->
  dictionary = {
    'EN':
      'app':
        'dont-show': "Don't Show Me Again"
      'app.top-picks':
        title: "Top Picks"
        'header-card':
          header: "Top Picks"
          body: "A selection of Top Picks from our Curators to help you re-live your favorite Moments"
          footer: ""
        'empty-list':
          header: 'You have no Top Picks'
          body: "Why don't you get started by sending us some old vacation photos?"
          buttonLabel: 'Choose Your Days'

      'app.top-picks.favorites':
        title: "Favorites"
        'header-card':
          header: "Favorites"
          body: "A selection of your Favorite Shots to help you re-live your favorite Moments"
          footer: "" 
      'app.top-picks.shared':
        title: "Shared"
        'header-card':
          header: "Shared"
          body: "A selection of Top Picks and Favorite Shots you have Shared from this App"
          footer: ""


      'app.choose':
        title: "Choose Your Days"

      'app.choose.camera-roll': 
        'header-card':
          header: "When were you On-The-Go?"
          body: "Back home already? Choose the days you want to re-live, and we'll find the beautiful moments in your Camera Roll"
          footer: ""
      'app.choose.calendar': 
        'header-card':
          header: "When will you be On-The-Go?"
          body: "Planning a trip? Choose the days you hope to re-live and go capture some beautiful moments. We'll take care of the rest."
          footer: "" 
      'app.checkout.order-detail': {}
      'app.checkout.payment': {}
      'app.checkout.sign-up': {}
      'app.checkout.terms-of-service': {}
      'app.checkout.submit': {}
      'app.checkout.complete': {}
      'app.orders': {}
      'app.orders-detail': {}
      'app.uploader': 
        warning:
          offline: "Please connect to a network."
          cellular: "Upload by cellular data is disabled."
      'app.settings.main': {}
      'app.settings.profile': {}
      'app.settings.sign-in': {}
      'app.settings.legal':
        title: 'Legal'
        tos: "Terms of Use"
        'tos-agree': "By checking this box, I acknowledge that I have read, understand, and agree to Snaphappi’s Terms of Use and Privacy Policy."
        privacy: "Privacy"
      'app.settings.terms-of-service': {}
      'app.help.main': {}
      'app.help.welcome': {}
      'app.help.pricing': {}
  }

  self = {
    _lang: 'EN'
    lang: (lang)->
      self._lang = lang if lang
      return self._lang
    tr: (key, $state)->
      stateName = $state?.current?.name || $state || null
      stateName = $rootScope.$state?.current.name if !stateName
      return if !stateName
      msg = dictionary[ self._lang ][ stateName ]?[ key ] || ['MISSING',self._lang, stateName, key].join(':')
      return msg
    merge: (updatedDict, lang)->
      return _.merge( dictionary[lang], updatedDict[lang]  ) if lang
      return _.merge dictionary, updatedDict
  }
  return self
]



