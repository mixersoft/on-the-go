'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:ChooseCtrl
 # @description
 # # ChooseCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.controller 'CheckoutCtrl', [
  '$scope', '$rootScope', '$state', '$q', 
  '$ionicNavBarDelegate', '$ionicHistory', '$ionicModal', '$ionicScrollDelegate'
  'otgData', 'otgWorkorder', 'otgUploader', 'otgParse', 'otgProfile', 'cameraRoll', 'snappiMessengerPluginService', 'TEST_DATA',
  ($scope, $rootScope, $state, $q, $ionicNavBarDelegate, $ionicHistory, $ionicModal, $ionicScrollDelegate, 
    otgData, otgWorkorder, otgUploader, otgParse, otgProfile, cameraRoll, snappiMessengerPluginService
    TEST_DATA) ->
    $scope.label = {
      title: "Checkout"
      header_card: 
        'order-detail+app.choose.camera-roll':
          header: "Order Details"
          body: "These are the days you will have us scan:"
          footer: ""    
        'order-detail+app.choose.calendar':
          header: "Order Details"
          body: "Bon voyage! Have a great trip! It's so exciting to be On-The-Go - don't forget to snap a lot of photos.
          We'll keep an eye out for anything photos you take on these days: "
          footer: ""
        'payment':
          header: "Payment"
          body: ""
          footer: ""  
        'sign-up':
          header: "Sign-up"
        'terms-of-service':
          header: "Terms of Service"
        'submit':
          header: "Review"
          body: "Please review your order below"
          footer: "" 
        'complete':
          header: "What Happens Next?"
          body: ""
          footer: ""   
    }

    $scope.otgWorkorder = otgWorkorder

    # checkout wizard navigation
    _wizard = {
      doneState: 'app.uploader'
      steps : ['from','order-detail', 'payment', 'sign-up', 'submit', 'complete']
      from: (from)->
        _wizard.steps[0] = from if from # set state for back to Choose
        return _wizard.steps[0]

      
      validateSteps: ()->
        _wizard.steps.splice(_wizard.steps.indexOf('sign-up'), 1) if !!$scope.user.username && _wizard.steps.indexOf('sign-up')>-1
        _wizard.steps.splice(_wizard.steps.indexOf('terms-of-service'), 1) if !!$scope.user.tos && _wizard.steps.indexOf('terms-of-service')>-1
        return _wizard.steps

      goto : (dir, params=null)->
        steps = _wizard.steps
        current = $state.current.name.split('.').pop()
        try
          incr = if dir=='next' then 1 else if dir == 'prev' then -1 else if _.isNumeric(dir) then dir else 0
          target = steps[steps.indexOf(current)+incr]
          if target == steps[0] # back to Choose
            $state.go(target)
          else 
            $state.go('^.'+target, params)
        catch ex 
          if !target && current == _wizard.steps[_wizard.steps.length-1] 
            $state.go(_wizard.doneState)
          else 
            console.error "ERROR: invalid state transition in checkout, target="+target
        return
    }

    # use dot notation for scope
    $scope.on = {
      back : (params)-> 
        # _wizard.goto('prev', params)
        # $ionicNavBarDelegate.back()
        return $ionicHistory.goBack() if $ionicHistory.backView()
        $state.transitionTo( _wizard.from() )

      next : (params)-> 
        retval = $scope.on.beforeNextStep()
        if retval.then?  # a promise
          return retval.then (o)->
              _wizard.goto('next', params)
            , (error)->
              console.warn "wizard beforeNextStep returned FALSE by promise!!!"
        else 
          return if !retval
        _wizard.goto('next', params)
      getOrderType: ()->
        # camera-roll or calendar
        from = _wizard.steps[0].split('.').pop()
        return if !from || from=='from' then 'camera-roll' else from
      getHeaderCard: ()->
        step = $state.current.name.split('.').pop()
        if step=='order-detail'
          target = _wizard.steps[1]+'+'+_wizard.steps[0] 
          header = $scope.label.header_card[ target ]
        else 
          header = $scope.label.header_card[step]
        return header
      currentState : ()->
        console.log $state.current.name
        return $state.current.name
      beforeNextStep: ()->
        # before you leave!!!
        switch $state.current.name
          when 'app.checkout.sign-up'
            # return false on error by promise
            return $scope.otgProfile.submitP() if $scope.otgProfile.dirty

          when 'app.checkout.payment'
            if !$scope.user.tosAgree
              # TODO: notify TOS must be checked
              el = document.getElementById('tos-checkbox')
              angular.element(el).addClass('item-assertive').removeClass('item-calm')
              return false 

            if $scope.watch.servicePlan.total != 0
              # offer additional coupon?
              el = document.getElementById('promo-code-button')
              angular.element(el).addClass('button-assertive').removeClass('button-balanced')
              return false

          when 'app.checkout.submit'
            # return false on error by promise
            return parse._createWorkorderP( $scope.checkout, $scope.watch.servicePlan ).then (workorderObj)->
                $ionicNavBarDelegate.showBackButton(false)
                return
          when 'app.checkout.complete'
            return true
            
        return true
      afterNextStep: ()->
        switch $state.current.name
          when 'app.checkout.payment'
            servicePlan = $scope.watch.servicePlan
            if servicePlan.plans.indexOf("Promo Code: " + "3DAYSFREE") == -1
              promoCode = "3DAYSFREE"
              promoCodeLabel = {
                copy: "It's your lucky day! For a limited time, all the cool kids can get a special promo code!"
                button: "I'm Cool, Gimme a Code!"
              }
            else if servicePlan.plans.indexOf("Promo Code: " + "IWILLGIVEFEEDBACK") == -1
              promoCode = "IWILLGIVEFEEDBACK"
              promoCodeLabel = {
                copy: "Aw snap! It looks like you will need some extra love for this order!"
                button: "I'll Have Another, Please :-D"
              }
            else 
              promoCode = null
              promoCodeLabel = {
                copy: "I'm sorry, you've gone over our limit for now..."
                button: ""
              }
            $scope.watch.promoCode = promoCode
            $scope.watch.promoCodeLabel = promoCodeLabel

          when 'app.checkout.complete'
            # AFTER submit, queue photos
            parse._queueSelectedMoments $scope.checkout, $scope.workorderObj


        # put on on $rootScope.$on '$stateChangeSuccess'
        # switch $state.current.name
        return true
      getPromoCode: (ev, swipeCard)->
        total = _applyPromoCode($scope.watch.promoCode, $scope.watch.servicePlan)
        el = ev.currentTarget
        # el = document.getElementById('promo-code-button')
        angular.element(el).addClass('button-balanced').removeClass('button-assertive')
        swipeCard.swipeOut() if !$scope.watch.servicePlan.total
        return true

      tosClick: (ev)->
        if $scope.user.tos 
          el = ev.currentTarget
          # el = document.getElementById('tos-checkbox')
          angular.element(el).addClass('item-calm').removeClass('item-assertive')
        return


      hide : (swipeCard)->
        swipeCard.el.parentNode.className += ' hide '
    }

    $scope.otgProfile = otgProfile

    $scope.watch = {
      promoCode: ''
      servicePlan: null
    }

    $scope.getItemHeight = (moment, index)->
      days = moment.value.length
      paddingTop = 10
      padding = 16+1
      h = days * (56+1) + padding * 2
      # console.log "i="+index+", moment.key="+moment.key+", h="+h
      return h

    
    # TODO: make camera-roll date HScroll to see all thumbs
    $scope.hScrollable = ($ev)->
      console.log "hScrollable(): make camera-roll-date H scrollable"
      return

    # ???: is there a better way to access controllerScope within an ng-repat
    $scope.controllerScope = _.pick($scope, [
      'localstate',
      'getItemHeight',
      'hScrollable'
    ])

    # $rootScope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams)->
    #   if toState.name.indexOf('app.checkout') == 0 
    #     if fromState.name.indexOf('app.payment') == 0
    #       # otgWorkorder.on.clearSelected()
        

    _getTotal = (checkout)->
      checkout = $scope.checkout if ! checkout
      servicePlan = {
        total: 0
        plans: []
      }
      if $state.params.from == 'app.choose.camera-roll' && checkout.count.photos <= 100 
        servicePlan.total = 1
        servicePlan.plans.push('First 100 Photos')
        return servicePlan
      total = 0
      months = Math.floor(checkout.count.days/30)
      if months 
        total = months * 10
        servicePlan.plans.push('$10/month for '+ months + ' months' )
      remainder = (checkout.count.days % 30)
      if remainder <= 5
        total += remainder * 1
        servicePlan.plans.push('$1/day for ' + remainder + ' days' )
      else if remainder <= 7
        total += 5
        servicePlan.plans.push('$5/week for 1 week' )
      else if remainder <= 11 
        total += 5 + (remainder-7)*1
        servicePlan.plans.push('$5/week for 1 week')
        servicePlan.plans.push('$1/day for ' + (remainder-7) + ' days' )
      else if remainder <= 30  
        total += 10
        if months
          servicePlan.plans[0]('$10/month for ' + (months + 1) + ' months' )
        else servicePlan.plans.push('$10/month for 1 month')
      servicePlan.total = total
      return servicePlan

    _applyPromoCode = (promoCode, servicePlan)->
      switch promoCode
        when '3DAYSFREE'
          if servicePlan.plans.indexOf("Promo Code: " + promoCode) == -1
            servicePlan.plans.push('Promo Code: ' + promoCode)
            servicePlan.total = Math.max( servicePlan.total - 3, 0)
        when 'IWILLGIVEFEEDBACK'
          if servicePlan.plans.indexOf("Promo Code: " + promoCode) == -1
            servicePlan.plans.push('Promo Code: ' + promoCode)
            servicePlan.total = Math.max( servicePlan.total - 10, 0)
      $scope.on.afterNextStep()
      return servicePlan.total


    parse = {
      _createWorkorderP : (checkout, servicePlan)->
        backlogStatus = null
        return otgParse.checkSessionUserP()
        .then otgParse.checkBacklogP
        .then (backlog)->
          backlogStatus = backlog.get('status')
          $scope.config.system['order-standby'] =  (backlogStatus == 'standby')
          options = {
            status: 'new'
            fromDate: checkout.dateRange.from
            toDate: checkout.dateRange.to
          }
          return otgParse.findWorkorderP(options)
        .then (results)->
            orderStatus = backlogStatus || 'new'
            return otgParse.createWorkorderP(checkout, servicePlan, orderStatus) if _.isEmpty(results)
            return results.shift()
          , (error)->
            return otgParse.createWorkorderP(checkout, servicePlan)
        .then (workorderObj)->
          $scope.workorderObj = workorderObj
          return workorderObj

      _queueSelectedMoments : (checkout, workorderObj)->
        workorderObj = $scope.workorderObj if !workorderObj

        # photos = parse.DEPRECATED_getPhotosFromMoments(checkout.selectedMoments)
        # TODO: need to push from cameraRoll.map() because not all photos are in cameraRoll.photos
        dateRange = checkout.dateRange
        mappedPhotos = cameraRoll.map() 
        mappedPhotos = cameraRoll.photos if _.isEmpty mappedPhotos
        photos = _.reduce mappedPhotos, (result, o)->
            o.date = cameraRoll.getDateFromLocalTime o.dateTaken if !o.date && o.dateTaken
            result.push o if dateRange.from <= o.date <= dateRange.to
            return result
          , []

        queue = otgUploader.queue(workorderObj, photos)
        console.log "workorder created successfully and photos queued, length=" + queue.length
        return $q.when(queue)
    }

    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams)->
      if /^app.checkout/.test(toState.name) && /^app.checkout/.test(fromState.name)
        $scope.headerCard = $scope.on.getHeaderCard()
      if /^app.checkout/.test(toState.name)
        $scope.on.afterNextStep()


    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
            # once per controller load, setup code for view
      # register handlers for native uploader
      snappiMessengerPluginService.on.didFinishAssetUpload(otgUploader.uploadPhotoFileComplete)
      console.log '\n\n ***** handler registered for didFinishAssetUpload'
      console.log otgUploader.uploadPhotoFileComplete

      snappiMessengerPluginService.on.didBeginAssetUpload (resp)->
          console.log "\n\n ***** didBeginAssetUpload"
          console.log resp
          return
      return

    $scope.$on '$ionicView.beforeEnter', ()->
      # cached view becomes active 
      init()
      return

    $scope.$on '$ionicView.leave', ()->
      # cached view becomes in-active 
      return 

    init = ()->
      $scope.orders = []

      otgParse.checkSessionUserP() # register anonymous user/guest here(?)
      otgParse.checkBacklogP().then (backlog)->
        $scope.config.system['order-standby'] = backlog.get('status') == 'standby'

      console.log "init: state="+$state.current.name
      $scope.checkout = otgWorkorder.checkout.getSelectedAsMoments()
      $scope.watch.servicePlan = _getTotal($scope.checkout)
      _wizard.validateSteps()

      # initialize the wizard steps      
      if $state.params.from?
        _wizard.from($state.params.from)
      if !otgWorkorder.isSelected()
        target = 'app.choose.' + $scope.on.getOrderType()
        console.log "WARNING: checkout with no days selected!! redirecting, from="+target
        return $state.transitionTo(target)

      # get header_card data from state     
      $scope.headerCard = $scope.on.getHeaderCard()


      return


    # refactor to AppCtrl or service
    $ionicModal.fromTemplateUrl('partials/modal/pricing', {
        scope: $scope,
        animation: 'slide-in-up'
      }).then( (modal)-> 
        $scope.pricelist = modal
      )    
    $scope.$on('$destroy', ()->
      $scope.pricelist.remove();
    );




    window.debug = _.extend window.debug || {} , {
        watch: $scope.watch
        checkout: $scope.checkout
      }

  ]