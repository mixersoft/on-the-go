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
  'cameraRoll', 'otgData', 
  (cameraRoll, otgData)->
    # convert to a service, one instance for each order, including 'new'
    _moments = cameraRoll.moments
    _data = []
    _selected = _.clone _reset = {
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
        return otgData.parsePhotosFromMoments _selected.moments, cameraRoll.map()


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
          to = from if !to
          _data = []
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
          # console.log "*** clearSelected!!!"
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
  '$scope', '$rootScope', '$state', '$stateParams', '$timeout', '$ionicModal', 'otgData', 'otgWorkorder', 'deviceReady', 'cameraRoll', 'snappiMessengerPluginService', 
  ($scope, $rootScope, $state, $stateParams, $timeout, $ionicModal, otgData, otgWorkorder, deviceReady, cameraRoll, snappiMessengerPluginService) ->

    $scope.otgWorkorder = otgWorkorder
    
    _datepicker = {
      instance: null # set in '$ionicView.loaded'
      WEEKS_TO_SHOW : 5
      datePickerOptions: 
        # autofocus: true
        format: 'd mmm, yyyy'
        formatSubmit: 'yyyy-mm-dd'
        hiddenName: true
        firstDay: 1
        editable: true
        container: document.getElementById('datepicker-wrap')
        containerId: 'datepicker-wrap'
        # min: null
        # max: null
        onBeforeSet: (newVal)->
          if newVal?.select
            selected = _datepicker._getAsLocalTime(new Date(newVal.select), true)[0...10]
          else 
            selected = newVal
          # selected = _datepicker.instance.get('select', $scope.watch.datePickerOptions.formatSubmit)
          dateRange = _datepicker.dateRange(selected)
          # console.log dateRange
          return
        isSelected: (targetDate)->
          date = _datepicker._getAsLocalTime(targetDate.obj, true)[0...10]
          selectedRange = _datepicker.dateRange()
          return true if selectedRange.from == date
          return false if !selectedRange.to
          isBetween = selectedRange.from <= date <= selectedRange.to
          return isBetween
      _getAsLocalTime : (d, asJSON=true)->
        d = new Date() if !d    # now
        throw "_getAsLocalTimeJSON: expecting a Date param" if !_.isDate(d)
        d.setHours(d.getHours() - d.getTimezoneOffset() / 60)
        return d.toJSON() if asJSON
        return d    
      getMon : (today)->
          day = today.getDay()
          diff = today.getDate() - day 
          diff +=  if day == 0 then -6 else 1 
          return new Date( today.setDate(diff) )
      getDatePickerRange : (numWeeks = 5)->
        datePickerRange = {
          min: _datepicker.getMon( new Date() )
        }
        datePickerRange.max = new Date(  )
        datePickerRange.max.setDate( datePickerRange.min.getDate() + (7 * numWeeks)  )
        return datePickerRange
      dateRange : (selected)->
        dateRange = $scope.watch.dateRange
        return dateRange if !selected
        if selected == 'clear'
          dateRange.from = null
          dateRange.to = null
          # calendar = _datepicker.instance.component
        else if !dateRange.from 
          dateRange.from = selected
          # dateRange.to = null
        else if selected < dateRange.from
          dateRange.to = dateRange.from if !dateRange.to
          dateRange.from = selected
          
        else if selected >= dateRange.from
          dateRange.to = selected
        return dateRange
      activate : ()->
        options = _datepicker.getDatePickerRange(_datepicker.WEEKS_TO_SHOW)
        _.extend $scope.watch.datePickerOptions, options
        input = document.getElementById('datepicker-input')

        _waitForRender = ()->
          input = document.getElementById('datepicker-input')
          return $timeout _waitForRender, 100 if !input

          # console.log "datepicker activate ***"
          selected = _datepicker.dateRange()
          otgWorkorder.on.selectByCalendar(selected.from, selected.to) if selected.from
          window.P = _datepicker.instance.start().open(true)

        if !input
          $timeout _waitForRender, 100 
        else   
          _waitForRender()
          
        return

      deactivate : ()->
        _datepicker.instance.stop()
        return

    }



    $scope.watch = {
      cameraRoll: cameraRoll
      datePickerOptions: _datepicker.datePickerOptions
      dateRange:
        from: null
        to: null
        selected: null  # last selected as Date()

    }
    debug.dateRange = $scope.watch.dateRange

    $scope.$watch 'watch.dateRange', (newVal, oldVal)->
        if !newVal.from
          return otgWorkorder.on.clearSelected()
        otgWorkorder.on.selectByCalendar(newVal.from, newVal.to)
        return 
      , true

    $rootScope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams)->
      if toState.name.indexOf('app.choose') == 0 
        if fromState.name.indexOf('app.checkout') == 0
          # console.log "BACK BUTTON DETECTED from checkout????? " + fromState.name + ' > ' + toState.name
        else
          # console.log "state.transitionTo: " + fromState.name + ' > ' + toState.name
          switch toState.name
            when 'app.choose.calendar'
              return otgWorkorder.on.clearSelected()
            when 'app.choose.camera-roll'
              # return
              return otgWorkorder.on.clearSelected()


    $scope.$on 'cameraRoll.loadPhotosComplete', (ev, options)-> 
      return if options.type != 'moments'
      $rootScope.$broadcast('scroll.refreshComplete')
      # console.log "\n\n %%% watched cameraRoll.moments change, update filter %%% \n\n"
      return


    $scope.$on '$ionicView.loaded', ()->
      # once per controller load, setup code for view
      if !_datepicker.instance
        _datepicker.instance = angular.element(document.getElementById('datepicker-input')).data('pickadate')
        window.debug.P = _datepicker.instance
      return


    $scope.$on '$ionicView.beforeEnter', ()->
      # see: $scope.on.cameraRollSelected(), calendarSelected()
      return 

    $scope.$on '$ionicView.enter', ()->
      return 


    $scope.$on '$ionicView.beforeLeave', ()->
      # cached view becomes in-active 
      # _datepicker.deactivate() # deactivate in on.calendarDeselected()


    init = ()->
      return

      # skip DEBUG
      # switch $state.current.name
      #   when 'app.choose.calendar'
      #     otgWorkorder.on.clearSelected()
      #     return otgWorkorder.on.selectByCalendar("2014-09-20", "2014-09-24")
      # return

    # refactor to AppCtrl or service
    $ionicModal.fromTemplateUrl('views/partials/modal-pricing.html', {
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
        # console.log "hScrollable(): make camera-roll-date H scrollable"
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
      clearSelected : (ev)->
        if $state.includes('app.choose.calendar')
           angular.element(_datepicker.instance.$root[0].querySelectorAll('[data-clear]')).triggerHandler('click')
        else 
          otgWorkorder.on.clearSelected(ev)
        return
      calendarSelected : (value)->
        $timeout ()->
          # wait until input is rendered
          _datepicker.activate()

        return
      calendarDeselected : (value)->
        _datepicker.deactivate()
        return
      cameraRollSelected : (value)->
        if $scope.watch.favorites_initialized!=true
          $scope.watch.favorites_initialized = true
          cameraRoll.loadCameraRollP({type:'moments'}, 'merge')
          markup = '<div class="text-center"><i class="icon ion-load-b ion-spin"></i>&nbsp;scanning camera roll...</div>'
          $scope.notifyService.message markup, 'info', 5000
        else 
          cameraRoll.loadCameraRollP({type:'moments'}, false)  
        return true

      refresh: ()->
        return if $scope.deviceReady.device().isDevice == false
        cameraRoll.loadCameraRollP({type:'moments'}, 'merge')
        .then ()->
          # done on 'cameraRoll.loadPhotosComplete'
          return


    }



  ]