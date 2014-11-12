'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:ChooseCtrl
 # @description
 # # ChooseCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
# uses $q.promise to load src 
.directive 'lazySrc', [
  'TEST_DATA'
  (TEST_DATA)->
    return {
      restrict: 'A'
      scope: false
      link: (scope, element, attrs) ->
        uuidExt = attrs.lazySrc
        options = scope.options
        qGetSrc = scope.qGetSrc
        lorempixelSrc = TEST_DATA.lorempixel.getSrc(uuidExt, options.thumbnailSize, options.thumbnailSize, TEST_DATA)
        # lorempixelSrc = 'http://lorempixel.com/'+options.thumbnailSize+'/'+options.thumbnailSize+'?'+uuidExt
        element.attr('src', lorempixelSrc)
        if qGetSrc && uuidExt.length == 40
          qGetSrc(uuidExt).then (dataUrl)->
            console.log "return from lazy-src directive getSrc()"
            element.attr('src', dataUrl)

  }
]
.directive 'otgMoment', [
  '$window', 'otgWorkOrder', 'otgData'
  ($window, otgWorkOrder, otgData)->
    options = defaults = {
      breakpoint: 480
      'col-xs': 
        btnClass: ''
        thumbnailSize: 58-2
        thumbnailLimit: null # (w-69)/thumbnailSize
      'col-sm':
        btnClass: 'btn-lg'
        thumbnailSize: 74-2
        thumbnailLimit: null # (w-88)/thumbnailSize
    }

    _setSizes = (element)->
      # also $window.on 'resize'  
      w = element[0].parentNode.clientWidth
      # console.log w
      if w < options.breakpoint
        cfg = _.clone options['col-xs']
        cfg.thumbnailLimit = (w-69)/cfg.thumbnailSize
      else # .btn-lg
        cfg = _.clone options['col-sm']
        cfg.thumbnailLimit = (w-88)/cfg.thumbnailSize

      whitespace = cfg.thumbnailLimit % 1
      # console.log "whitespace=" + whitespace + ", pixels=" +(whitespace * cfg.thumbnailSize)
      if whitespace * cfg.thumbnailSize < 28 
        # leave room for .badge
        cfg.thumbnailLimit -= 1
      cfg.thumbnailLimit = Math.floor(cfg.thumbnailLimit)  
      # console.log "directive:otgMoment thumbnailLimit=" + cfg.thumbnailLimit
      return cfg

    _lookupPhoto = null
    _getAsPhotos = (uuids)->
      return _.map uuids, (uuidExt)->
        return _.findWhere _lookupPhoto, {id: uuidExt}

    return {
      templateUrl: 'views/template/moment.html'
      restrict: 'EA'
      scope : 
        moments: '=otgModel'
      # replace: true
      # require: ''
      link: (scope, element, attrs) ->
        # element.text 'this is the moment directive'
        scope.options = _setSizes(element)
        scope.getAsPhotos = _getAsPhotos
        _lookupPhoto = otgData.parsePhotosFromMoments scope.moments if !_lookupPhoto

        # TODO: these scope methods should be delegated
        scope.controllerScope = scope.$parent.controllerScope
        scope.otgWorkOrder = otgWorkOrder
        scope.ClassSelected = scope.$parent.ClassSelected
        return
      }
]
.factory 'otgWorkOrder', [
  ()->
    _moments = null
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

      countSelectedPhotos: ()->
        _selected.selectedPhotos =  _.reduce _data, (result, day)->
            result += day.value.length
            return result
          , 0
        return _selected.selectedPhotos

      setMoments: (moments)->
        _moments = moments || []


      getContiguousPhotos: ()->
        return otgData.parsePhotosFromMoments _selected.moments


      countContiguousPhotos: ()->
        return console.warn "WARNING: _moments not set, call otgWorkOrder.setMoments()" if !_.isArray(_moments)
        dateRange = self.getDateRange()
        _selected.days = (new Date(dateRange.to) - new Date(dateRange.from))/(24*60*60*1000) + 1

        selectedMoments = {}
        contiguousPhotos = 0
        _.each _moments, (moment)->
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
  '$scope', '$rootScope', '$state', '$stateParams', '$ionicModal', 'otgData', 'otgWorkOrder', 'TEST_DATA',
  ($scope, $rootScope, $state, $stateParams, $ionicModal, otgData, otgWorkOrder, TEST_DATA) ->
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

    $scope.otgWorkOrder = otgWorkOrder

    $scope.localstate = {
      showDelete: false
      showReorder: false
      canSwipe: true
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

    $rootScope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams)->
      if toState.name.indexOf('app.choose') == 0 
        if fromState.name.indexOf('app.checkout') == 0
          console.log "BACK BUTTON DETECTED from checkout????? " + fromState.name + ' > ' + toState.name
        else
          console.log "state.transitionTo: " + fromState.name + ' > ' + toState.name
          switch toState.name
            when 'app.choose.calendar', 'app.choose.TEST'
              otgWorkOrder.on.clearSelected()
              return otgWorkOrder.on.selectByCalendar("2014-09-20", "2014-09-24")
            when 'app.choose.camera-roll'
              # return
              return otgWorkOrder.on.clearSelected()

         

    

    init = ()->
      # console.log "init: state="+$state.current.name
      switch $state.current.name
        when 'app.choose.calendar'
          otgWorkOrder.on.clearSelected()
          return otgWorkOrder.on.selectByCalendar("2014-09-20", "2014-09-24")


      window.debug = _.extend window.debug || {} , {
        state: $state
      }
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
      dontShowHint : (hide, keep)->
        # check config['dont-show-again'] to see if we should hide hint card
        current = $scope.$state.current.name.split('.').pop()
        if hide?.currentTarget
          target = ionic.DomUtil.getParentOrSelfWithClass(hide.currentTarget, 'card')
          return target.swipeCard.swipeOut('left')
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