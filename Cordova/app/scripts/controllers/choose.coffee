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
  'deviceReady', 'cameraRoll', 'imageCacheSvc', '$rootScope', 'TEST_DATA'
  (deviceReady, cameraRoll, imageCacheSvc, $rootScope, TEST_DATA)->

    _setLazySrc = (element, UUID, format)->
      throw "ERROR: asset is missing UUID" if !UUID
      IMAGE_SIZE = format || 'thumbnail'

      # priorities: stashed FileURL > cameraRoll.dataURL > photo.src
      photo = element.scope().item

      isWorkorder = $rootScope.$state.includes('app.workorders') || $rootScope.$state.includes('app.orders')
      isWorkorderMoment = IMAGE_SIZE=='thumbnail' && isWorkorder
      isBrowser = !deviceReady.isWebView()

      # special condition, Editor Workstation with no local photos
      if isBrowser && photo?.from == 'PARSE' 
        # orders or workorders from PARSE, use photo.src
        if format == 'thumbnail'
          # TODO: workorder thumbnails should be resampled.
          "skip"
        url = cameraRoll.addParseURL(photo, format) # cache photo.src into dataURL
        return element.attr('src', url)  

      if isBrowser && photo && photo.from == 'PARSE' 
        # DEBUG mode on browser
        return element.attr('src', photo.src)  

      # return if isBrowser && !photo # digest cycle not ready yet  

      if isBrowser
        return _useLoremPixel(element, UUID, format)


      return imageCacheSvc.isStashed_P(UUID, format)
      .then (fileURL)->
        # 1. use isStashed FileURL
        element.attr('src', fileURL)
        return 
      .catch (error)->

        # NOTE: UUID is truncated to 36
        src = cameraRoll.getDataURL(UUID, IMAGE_SIZE) 
        if src  
          # 2. use cached cameraRoll.dataURLs
          # already cached in cameraRoll.dataURLs, but not yet stashed because of $timeout
          element.attr('src', src) 
          return 
        
        console.log "\nlazySrc reports notCached in cameraRoll.dataURLs for format=" + format + ", UUID="+UUID
        if !isBrowser || isWorkorder
          # get with promise
          return cameraRoll.getDataURL_P( UUID, IMAGE_SIZE ).then (photo)->
              if element.attr('lazy-src') == photo.UUID
                # confirm that collection-repeat has not reused the element
                # 3. fetch dataURL from cameraRoll, cache and stash
                element.attr('src', photo.data)
                if IMAGE_SIZE == 'preview'
                  imageCacheSvc.cordovaFile_USE_CACHED_P(element, photo.UUID, photo.data) 
                # ???: are thumbnails cached in preload?
              else
                console.warn "\n\n*** WARNING: did collection repeat change the element before getDataURL_P returned?"  
              return
          .catch (error)->
            console.error "_setLazySrc"
            console.error error # $$$
        

    _useLoremPixel = (element, UUID, format)->
      scope = element.scope()
      switch format
        when 'thumbnail'
          options = scope.options  # set by otgMoment`
          src = TEST_DATA.lorempixel.getSrc(UUID, options.thumbnailSize, options.thumbnailSize, TEST_DATA)
        when 'preview'
          src = scope.item?.src
          src = TEST_DATA.lorempixel.getSrc(UUID, scope.item.originalWidth, scope.item.originalHeight, TEST_DATA) if !src
      return element.attr('src', src)  # use ng-src here???


    return {
      restrict: 'A'
      scope: false
      link: (scope, element, attrs) ->
        format = attrs.format

        attrs.$observe 'lazySrc', (UUID)->
          # UUID = UUID[0...36] # localStorage might balk at '/' in pathname
          # console.log "\n\n $$$ attrs.$observe 'lazySrc', UUID+" + UUID
          element.attr('uuid', UUID)
          return src = _setLazySrc(element, UUID, format) 

        return
  }
]
.directive 'otgMoment', [
  # renders moment as a list of days
  '$window', 'otgWorkorder', 'cameraRoll', 'otgData'
  ($window, otgWorkorder, cameraRoll, otgData)->
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
      w = window.innerWidth
      # console.log w
      if w < options.breakpoint
        cfg = _.clone options['col-xs']
        cfg.thumbnailLimit = (w-69)/cfg.thumbnailSize
      else # .btn-lg
        cfg = _.clone options['col-sm']
        cfg.thumbnailLimit = (w-88)/cfg.thumbnailSize

      whitespace = cfg.thumbnailLimit % 1
      # console.log "whitespace=" + whitespace + ", pixels=" +(whitespace * cfg.thumbnailSize)
      if whitespace * cfg.thumbnailSize < 50 
        # leave room for .badge
        cfg.thumbnailLimit -= 1
      cfg.thumbnailLimit = Math.floor(cfg.thumbnailLimit)  
      # console.log "directive:otgMoment thumbnailLimit=" + cfg.thumbnailLimit
      return cfg

    _lookupPhoto = null
    _getAsPhotos = (uuids)->
      return _.map uuids, (uuid)->
        return _.findWhere _lookupPhoto, {UUID: uuid}

    _getMomentHeight = (moment, index)->
      days = moment.value.length
      paddingTop = 10
      padding = 16+1
      h = days * (this.options.thumbnailSize+1) + padding * 2
      # console.log "i="+index+", moment.key="+moment.key+", h="+h
      return h  

    _getOverflowPhotos = (photos)->
      # console.log "\n\n_getOverflowPhotos  ** photo.length=" + photos.length+"\n"
      return count = Math.max(0, photos.length - this.options.thumbnailLimit )


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
        _lookupPhoto = otgData.parsePhotosFromMoments cameraRoll.moments if !_lookupPhoto
        scope.getMomentHeight = _getMomentHeight
        scope.getOverflowPhotos = _getOverflowPhotos
        scope.otgWorkorder = otgWorkorder
        scope.ClassSelected = scope.$parent.ClassSelected
        return
      }
]
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