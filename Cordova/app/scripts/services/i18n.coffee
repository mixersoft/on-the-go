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
        'anon-username': 'anonymous'
      'app.top-picks.top-picks':
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

      'app.checkout':
        title: 'Checkout'
      'app.checkout.order-detail': {}
      'app.checkout.payment': {
        'header-card':
          header: 'Payment'
          body: ""
          footer: ""    
        'promo-card':
          header: 'Special Promo Codes'
        'legal-card':
          header: 'Legal'
          tos: 'Read our Terms of Use'
        promoCodes:
          '3DAYSFREE':
            code: '3DAYSFREE'
            copy: "It's your lucky day! For a limited time, all the cool kids can get a special promo code!"
            button: "I'm Cool, Gimme a Code!"
          'IWILLGIVEFEEDBACK':  
            code: 'IWILLGIVEFEEDBACK'
            copy: "Aw snap! It looks like you will need some extra love for this order!"
            button: "I'll Have Another, Please :-D"
          '_NULL_':
            code: ''
            copy: "I'm sorry, you've gone over our limit for now..."
            button: ''            
      }
      'app.checkout.sign-up': {
        'header-card':
          header: 'Sign-up'
      }
      'app.checkout.terms-of-service': {
        'header-card':
          header: 'Terms of Service'
      }
      'app.checkout.submit': 
        standby:
          header: 'Order Standby'
          body: """
            Our apologies - we have reached our order processing limit for the moment. 
            You may continue with your order, but it will be placed on standby with no scheduled date for processing. 
            We will notify you when the status changes, and your order will not be charged until work begins.
          """
      'app.checkout.complete': {}
      'app.orders': 
        standby:
          header: 'Order Standby'
          body: """
            Our apologies - we have reached our order processing limit for the moment.
            This order is currently on 'standby' with no scheduled date for processing. 
            However, you may continue to upload photos for this order. 
            We will notify you when the status changes, and your order will not be charged until work begins.
          """
      'app.orders-detail': {}
      'app.uploader': 
        warning:
          offline: "Please connect to a network."
          cellular: "Upload by cellular data is disabled."
      'app.settings':
        'error-codes':
          '101': "The Username and Password combination was not found. Please try again."
          '202': "That Username was already taken. Please try again."
          '203': "That Email address was already taken. Please try again."
          '10': "Sign-in unsucessful. Please try again."
          '11': "Sign-up unsucessful. Please try again."

      'app.settings.main': {}
      'app.settings.profile':
        aaa: 
          'submit': 'Submit'
          'sign-in': 'Sign in'
          'sign-out': 'Sign out'
          'profile': 'Profile'
          'email-verify': 'Resend Email Verification'

      'app.settings.sign-in': 
        'user': 'Username'
        'pass': 'Password'
        'submit': 'Submit'
        
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



