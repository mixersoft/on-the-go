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
          header: 'You have no Top Picks yet'
          choose: "Why don't you get started by sending us some old vacation photos?"
          upload: "Please make sure you have uploaded the photos from your order."
          buttonLabelChoose: 'Choose Your Days'
          buttonLabelUpload: 'Upload Photos'

      'app.top-picks.favorites':
        title: "Favorites"
        'header-card':
          header: "Favorites"
          body: "A selection of your Favorite Shots to help you re-live your favorite Moments. These include your favorites from other photo Apps"
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
        title: 'Order History'
        standby:
          header: 'Order Standby'
          body: """
            Our apologies - we have reached our order processing limit for the moment.
            This order is currently on 'standby' with no scheduled date for processing. 
            However, you may continue to upload photos for this order. 
            We will notify you when the status changes, and your order will not be charged until work begins.
          """
      'app.orders.detail': {}
      'app.orders.open': 
        title: 'Open Orders'
      'app.orders.complete': 
        title: 'Complete Orders'        
      'app.uploader': 
        title: 'Uploader'
        warning:
          offline: "Please connect to a network."
          cellular: "Upload by cellular data is disabled."
      'app.settings':
        'error-codes':
          '101': "Sorry, we didn't recognize that username and password. Please try again."
          '202': "That username was already taken. Please try again."
          '203': "That Email address was already taken. Please try again."
          '10': "Sign-in unsucessful. Please try again."
          '11': "Sign-up unsucessful. Please try again."
          '301': "You don't have permission to make those changes."

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
      'app.workorders.open': 
        title: 'Open Workorders'
      'app.workorders.complete': 
        title: 'Complete Workorders'
      'app.workorders.detail': 
        title: 'Workorder Detail'  

      # demo only  
      'app.demo':
        title: 'Behind The Scenes'
      'app.demo.all': 
        'header-card':
          header: 'Before'
          body: 'This is what our Curators see when you send us a new order. The photos come straight from your Camera Roll and include every burst mode, HDR version, and even (ahem...) the mistakes'
      'app.demo.picks':
        'header-card':
          header: 'After'
          body: "Our Curators scan your photos from great shots and hide the duplicates. You get all your Top Picks at the tip of your fingers."      
  }

  self = {
    _lang: 'EN'
    lang: (lang)->
      self._lang = lang if lang
      return self._lang
    tr: (key, state=null, stateIncludes)->
      # HACK: fix race condition when returning from workorder/left-side-menu
      return null if stateIncludes? && !$rootScope.$state.includes(stateIncludes)

      stateName = state || $rootScope.$state?.current.name
      return if !stateName
      msg = dictionary[ self._lang ][ stateName ]?[ key ] 
      if !msg
        # console.warn "i18n error, $state=" +  [$rootScope.$state.current.name, key].join(':')
        msg = ['MISSING',self._lang, stateName, key].join(':')
      return msg
    merge: (updatedDict, lang)->
      return _.merge( dictionary[lang], updatedDict[lang]  ) if lang
      return _.merge dictionary, updatedDict
  }
  return self
]



