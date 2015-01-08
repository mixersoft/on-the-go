'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:ChooseCtrl
 # @description
 # # ChooseCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
#
.factory 'otgWorkorder', [ 
  'cameraRoll', 'otgData'
  (cameraRoll, otgData)->
    # convert to a service, one instance for each order, including 'new'
    _moments = cameraRoll.moments
    _data = []
    _selected = _reset = {
      selectedPhotos: 0
      contiguousPhotos: 0
      dateRange: 
        from: null
        to: null
      days: 0
      moments: {}
    }
    _existingOrders = []  # array of dateRanges

    #
    # Service for parsing WorkOrders
    #

    self = {
      # _data: null  # private, array initialize in init()
      # countPhotos: null
      isSelected: ()->
        # console.log "*** _data.length===0" if  _data.length == 0
        return _data.length > 0

      isDaySelected: (day)->
        found = _.find( _data, {key: day.key} )
        return found

      isDayIncluded: (day, existingOrder=false)->
        if !existingOrder
          return false if !_selected.dateRange.from || day.key < _selected.dateRange.from
          return false if !_selected.dateRange.to || day.key > _selected.dateRange.to 
          return false if self.isDaySelected(day)
          return true 
        else 
          # TODO: distinguish between new & existing orders
          found = false
          _.each _existingOrders, (dateRange)->
            if dateRange.from <= day.key <= dateRange.to
              found = true
              return false
          return found

      countSelectedPhotos: ()->
        _selected.selectedPhotos =  _.reduce _data, (result, day)->
            result += day.value.length
            return result
          , 0
        return _selected.selectedPhotos

      getContiguousPhotos: ()->
        return otgData.parsePhotosFromMoments _selected.moments


      countContiguousPhotos: ()->
        return console.warn "WARNING: _moments not set, call otgWorkorder.setMoments()" if !_.isArray(_moments)
        dateRange = self.getDateRange()
        _selected.days = (new Date(dateRange.to) - new Date(dateRange.from))/(24*60*60*1000) + 1

        selectedMoments = {}
        contiguousPhotos = 0
        _.each cameraRoll.moments, (moment)->
          found = false
          _.each moment.value, (day)->
            found = if dateRange.from <= day.key <= dateRange.to then day else false
            if found  
              selectedMoments[moment.key] =  {key: moment.key, type:'moment', value:[] } if !selectedMoments[moment.key]
              selectedMoments[moment.key].value.push(found) 
              contiguousPhotos += found.value.length
            return
          return
        _selected.moments = _.values selectedMoments
        return _selected.contiguousPhotos = contiguousPhotos


      countContiguousDays: ()->
        return _selected.days  

      getDateRange: ()->
        selected = _data
        selectedDates = _.pluck selected, "key"
        selectedDates.sort()
        _selected.dateRange.from = selectedDates[0]
        _selected.dateRange.to = selectedDates[selectedDates.length-1]
        _selected.days = (new Date(_selected.dateRange.to) - new Date(_selected.dateRange.from))/(24*60*60*1000) + 1
        return _selected.dateRange


      existingOrders:
        addExistingOrder: (dateRange)->
          found = _.find _existingOrders, dateRange
          _existingOrders.push dateRange if !found

        clearExistingOrder: (dateRange)->
          return _existingOrders = [] if !dateRange
          return _existingOrders = _.filter _existingOrders, dateRange

      checkout:
        getSelectedAsMoments: ()->
          self.countContiguousPhotos()
          # cache statistics
          return {
            selectedMoments : _selected.moments 
            dateRange: _selected.dateRange
            count:
              photos : _selected.contiguousPhotos
              days : _selected.days
          }

      # watch: _selected
      # data: ()->
      #   return _data

      humanize:
        orderSummary: (order)->
          summary = {}
          summary.from = new Date(order.checkout.from)

          return summary



      on: # methods available to directives
        selectByCalendar: (from, to)->
          _data.push({key:from, value: []})
          _data.push({key:to, value: []})
          return self.getDateRange()

        selectByCameraRollDate: ($ev)->
          $el = angular.element($ev.currentTarget)
          day = $el.scope().day
          if !self.isDaySelected(day)
            _data.push( day )
          else
            remove = _.findIndex(_data, ((o)-> return o.key == day.key)  )
            _data.splice(remove, 1)
          # cache statistics  
          self.countSelectedPhotos()
          self.countContiguousPhotos()
          # self.watch.isSelected = self.isSelected()
          return
        clearSelected: ()->
          console.log "*** clearSelected!!!"
          _data = []
          _.extend _selected, _reset
          return


    }

    window.debug = _.extend window.debug || {} , {
      wo: self
    }
    return self

]
.controller 'ChooseCtrl', [
  '$scope', '$rootScope', '$state', '$stateParams', '$timeout', '$ionicModal', 'otgData', 'otgWorkorder', 'deviceReady', 'cameraRoll', 'snappiMessengerPluginService', 'TEST_DATA',
  ($scope, $rootScope, $state, $stateParams, $timeout, $ionicModal, otgData, otgWorkorder, deviceReady, cameraRoll, snappiMessengerPluginService,TEST_DATA) ->
    $scope.label = {
      title: "Choose Your Days"
      header_card: 
        'app.choose.calendar': 
          header: "When will you be On-The-Go?"
          body: "Planning a trip? Choose the days you hope to re-live and go capture some beautiful moments. We'll take care of the rest."
          footer: ""
        'app.choose.camera-roll':
          header: "When were you On-The-Go?"
          body: "Back home already? Choose the days you want to re-live, and we'll find the beautiful moments in your Camera Roll"
          footer: ""  
    }

    $scope.otgWorkorder = otgWorkorder

    $rootScope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams)->
      if toState.name.indexOf('app.choose') == 0 
        if fromState.name.indexOf('app.checkout') == 0
          console.log "BACK BUTTON DETECTED from checkout????? " + fromState.name + ' > ' + toState.name
        else
          console.log "state.transitionTo: " + fromState.name + ' > ' + toState.name
          switch toState.name
            when 'app.choose.calendar', 'app.choose.TEST'
              otgWorkorder.on.clearSelected()
              return otgWorkorder.on.selectByCalendar("2014-09-20", "2014-09-24")
            when 'app.choose.camera-roll'
              # return
              return otgWorkorder.on.clearSelected()


    $scope.cameraRoll = cameraRoll
    $scope.$watchCollection 'cameraRoll.moments', (newV, oldV)->
      # console.log "\n\n %%% watched cameraRoll.moments change, update filter %%% \n\n"
      return if !deviceReady.isWebView()
      return cameraRoll.loadMomentThumbnailsP()


    init = ()->
      # console.log "init: state="+$state.current.name
      console.log "\n\n*** ChooseCtrl init() ***"

      return cameraRoll.loadMomentThumbnailsP() 

      # skip DEBUG
      switch $state.current.name
        when 'app.choose.calendar'
          otgWorkorder.on.clearSelected()
          return otgWorkorder.on.selectByCalendar("2014-09-20", "2014-09-24")
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

    $scope.on = {
      hScrollable : ($ev)->
        console.log "hScrollable(): make camera-roll-date H scrollable"
        return
      dontShowHint : (hide, keep)->
        # check config['dont-show-again'] to see if we should hide hint card
        current = $rootScope.$state.current.name.split('.').pop()
        if hide?.swipeCard
          property = $scope.config['dont-show-again']['choose']
          property[current] = true
          $timeout ()->
              return hide.swipeCard.resetPosition()
            , 500
          return 
        return $scope.config['dont-show-again']['choose']?[current]
    }


    init()


         

  ]