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
  '$ionicNavBarDelegate', '$ionicModal', '$ionicScrollDelegate'
  'otgData', 'otgWorkOrder', 'otgUploader', 'otgParse', 'otgProfile', 'cameraRoll',  'TEST_DATA',
  ($scope, $rootScope, $state, $q, $ionicNavBarDelegate, $ionicModal, $ionicScrollDelegate, otgData, otgWorkOrder, otgUploader, otgParse, otgProfile, cameraRoll, TEST_DATA) ->
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

    $scope.otgWorkOrder = otgWorkOrder

    # checkout wizard navigation
    _wizard = {
      doneState: 'app.uploader'
      steps : ['from','order-detail', 'payment', 'sign-up', 'terms-of-service', 'submit', 'complete']
      from: (from)->
        _wizard.steps[0] = from # set state for back to Choose
      
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
        $ionicNavBarDelegate.back()
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

          when 'app.checkout.terms-of-service'
            if !$scope.user.tos
              # TODO: notify TOS must be checked
              $ionicScrollDelegate.scrollBottom(true)
              return false 
          when 'app.checkout.submit'
            # return false on error by promise
            return parse._createWorkorderP( $scope.checkout, $scope.watch.servicePlan ).then (workorderObj)->
                # deprecate: /orders should fetch from parse instead of $scope.orders
                $scope.orders.push {
                  datetime: new Date()
                  status: 'new'
                  checkout: $scope.checkout
                  servicePlan: $scope.watch.servicePlan
                }
                $ionicNavBarDelegate.showBackButton(false)
                return $q.when(workorderObj)
          when 'app.checkout.complete'
            return true
            
        return true
      afterNextStep: ()->
        switch $state.current.name
          when 'app.checkout.complete'
            # AFTER submit, queue photos
            parse._queueSelectedMomentsP $scope.checkout, $scope.workorderObj


        # put on on $rootScope.$on '$stateChangeSuccess'
        # switch $state.current.name
        return true
      getPromoCode: ()->
        $scope.watch.promoCode = "3DAYSFREE"
        _applyPromoCode($scope.watch.promoCode, $scope.watch.servicePlan)
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
    #       # otgWorkOrder.on.clearSelected()
        

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
          return if servicePlan.plans.indexOf("Promo Code: " + promoCode) > -1
          servicePlan.plans.push('Promo Code: ' + promoCode)
          servicePlan.total = Math.max( servicePlan.total - 3, 0)

    parse = {
      _createWorkorderP : (checkout, servicePlan)->
        return otgParse.checkSessionUserP().then ()->
          options = {
            status: 'new'
            fromDate: checkout.dateRange.from
            toDate: checkout.dateRange.to
          }
          return otgParse.findWorkorderP(options)
        .then (results)->
            return otgParse.createWorkorderP(checkout, servicePlan) if _.isEmpty(results)
            return results.shift()
          , (error)->
            return otgParse.createWorkorderP(checkout, servicePlan)
        .then (workorderObj)->
          $scope.workorderObj = workorderObj
          return workorderObj


      DEPRECATED_getPhotosFromMoments : (moments)->
        # using reduce with dateRange instead
        return moments if moments[0]?.type != 'moment' 
        photoList = otgData.parsePhotosFromMoments moments
        lookup = cameraRoll.photos
        photos = _.map photoList, (o)->
          # map to lorempixel src
          return _.findWhere lookup, {UUID : o.UUID}

        return photos    # with photo.src as lorempixel  
          

      _queueSelectedMomentsP : (checkout, workorderObj)->
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

        return otgUploader.queueP(workorderObj, photos).then (queue)->
          console.log "workorder created successfully and photos queued, length=" + queue.length
          return $q.when(queue)
    }

    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams)->
      if /^app.checkout/.test(toState.name) && /^app.checkout/.test(fromState.name)
        $scope.headerCard = $scope.on.getHeaderCard()
      if /^app.checkout/.test(toState.name)
        $scope.on.afterNextStep()


    init = ()->
      # TODO: move to AppCtrl
      otgParse.checkSessionUserP().then ()->  
        check = $rootScope.user 
        return 

      console.log "init: state="+$state.current.name
      $scope.checkout = otgWorkOrder.checkout.getSelectedAsMoments()
      $scope.watch.servicePlan = _getTotal($scope.checkout)
      _wizard.validateSteps()
      $scope.$state = $state

      # initialize the wizard steps      
      if $state.params.from?
        _wizard.from($state.params.from)
      if !otgWorkOrder.isSelected()
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


    init()

    window.debug = _.extend window.debug || {} , {
        watch: $scope.watch
        checkout: $scope.checkout
      }

  ]