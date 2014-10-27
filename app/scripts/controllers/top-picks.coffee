'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:GalleryCtrl
 # @description
 # # GalleryCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.factory 'otgData', [
  ()->
    DAY_MS = 24*60*60*1000
    defaults_photo = {
        id: null
        date: null
        rating: null 
        favorite: false
    }
    self = {
      parsePhotosFromMoments : (moments)->
        photos = []
        _.each moments, (v,k,l)->
          if v['type'] == 'moment'
            _.each v['value'], (v2,k2,l2)->
              if v2['type'] == 'date'
                _.each v2['value'], (pid)->
                  photos.push _.defaults {
                      id: pid, 
                      date: v2['key']
                    }, defaults_photo

        # console.log photos 
        return photos

      # expecting { `date`: [array of photoIds]}
      parseMomentsFromCameraRollByDate : (cameraRollDates)->
        dates = _.keys cameraRollDates
        dates.sort()
        # console.log dates

        # cluster into moments
        _current = _last = null
        moments = _.reduce dates, (result, k)->
            date = if _.isDate(k) then k else new Date(k)
            if _current? 
              if date.setHours(0,0,0,0) == _last + DAY_MS # next day
                _last = date.setHours(0,0,0,0)
                _current.days[k] = cameraRollDates[k]
              else 
                _current = _last = null    

            if !_current?
              # ???: use $dateParser?
              _last = date.setHours(0,0,0,0)
              o = {}
              o[k] = cameraRollDates[k]
              _current = { label: k, days: o }
              result[_current.label] =  _current.days

            return result
          , {}
        # console.log moments 
        return moments

        # reformat object as an array of {key:, value: }
      orderMomentsByDescendingKey : (o, levels=1)->
          keys = _.keys( o ).sort().reverse()
          recurse = levels - 1
          reversed = _.map keys, (k)->
            item = { key: k }
            item.type = if recurse then 'moment' else 'date'
            item.value = if recurse > 0 then self.orderMomentsByDescendingKey( o[k], recurse ) else o[k]

            # console.log item
            return item
          # console.log reversed if levels==2
          return reversed  


    }
    return self 
  ]
.directive 'otgPreview', [
    '$window'
    ($window)->
      default_options = {
        width: 320
        height: 240
      }
      return {
        # templateUrl: 'views/template/otg-preview.html'
        template: '<img ng-src="{{photo.src}}" height="{{photo.height}}">'
        restrict: 'EA'
        scope : false
          # photo: "=photo"
        link: (scope, element, attrs) ->
          # element.text 'this is the moment directive'
          if !scope.$parent.options?.width
            scope.$parent.options = _.defaults (scope.$parent.options || {}), default_options
          options = _.clone scope.$parent.options 
          if !scope.photo?.height && (scope.photo.id[-5...-4]<'4')
            options.height = 400
          src = "http://lorempixel.com/"+(options.width)+"/"+(options.height)+"?"+scope.photo.id
          scope.photo.src = src
          # scope.photo.width = options.width
          scope.photo.height = options.height
          return
      }
  ]
.directive 'collectionRepeatScrollWrap', [ '$timeout'
    ($timeout)->
      return {
        restrict: 'A'
        scope: 
          resize : '&'
        link: (scope, element, attrs)->
          className = attrs.collectionRepeatScrollWrap   
          scope.$watch ()->
              return scope.resize()
            , (newV, oldV)->
              # wrap = ionic.DomUtil.getParentOrSelfWithClass(element[0], className)
              wrap = document.getElementsByClassName(className)
              return $timeout ()-> 
                  return angular.element(wrap).triggerHandler('scroll.resize')
                , 0
          return
      }
]
# fake filter for selecting 'favorites' & 'shared' photos from $scope.photos
.filter 'fake', ()->
  return (input, type='none')->
    switch type
      when 'none' 
        return input
      when 'favorites' 
        # match = '2468ACE'   # match last CHAR of UUID
        return _.reduce input, (result, e, i)->
            result.push(e) if e.favorite == true 
            return result
          , [] 
      when 'shared'
        return _.reduce input, (result, e, i)->
            result.push(e) if e.shared == true 
            return result
          , [] 
        # match = '2ACE'
    # return _.reduce input, (result, e, i)->
    #         result.push(e) if match.indexOf(e.id[-5...-4]) > 0 
    #         return result
    #       , [] 
      
.controller 'TopPicksCtrl', [
  '$scope', '$rootScope', '$state', 'otgData', '$timeout', '$window', '$ionicPopup', 'TEST_DATA', 'fakeFilter'
  ($scope, $rootScope, $state, otgData, $timeout, $window, $ionicPopup, TEST_DATA, fakeFilter) ->
    $scope.label = {
      title: "Top Picks"
      header_card: 
        'app.top-picks': 
          header: "Top Picks"
          body: "A selection of Top Picks from our Curators to help you re-live your favorite Moments"
          footer: ""
        'app.top-picks.favorites':
          header: "Favorites"
          body: "A selection of your Favorite Shots to help you re-live your favorite Moments"
          footer: ""  
        'app.top-picks.shared':
          header: "Shared"
          body: "A selection of Top Picks and Favorite Shots you have Shared from this App"
          footer: ""  
    }

    window.$state = $scope.$state = $state;

    $scope.state = {
      showDelete: false
      showReorder: false
      canSwipe: true
    };


    $scope.getItemHeight = (item, index)->
      # console.log "index="+index+", item.h="+item.height+" === index.h="+$scope.photos[index].height+", index.id="+$scope.photos[index].id
      h = $scope.filteredPhotos[index].height
      h += 90 if $scope.on.showInfo()
      return h

    # filter photos based on $state.current
    # TODO: use ion-tabs instead?
    setFilter = (toState)->
      switch toState.name
        when 'app.top-picks'
          $scope.filteredPhotos = fakeFilter($scope.photos,'none')
        when 'app.top-picks.favorites'
          $scope.filteredPhotos = fakeFilter($scope.photos,'favorites')
        when 'app.top-picks.shared'
          $scope.filteredPhotos = fakeFilter($scope.photos,'shared')
      return    

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true
      showInfo: (value=null)->
        return $scope.on._info if value == null 

        if value=='toggle'
          $scope.on._info = !$scope.on._info 
        else if value != null
          $scope.on._info = !value
        # # fire 'scroll.resize' to renderOnResize collection-repeat
        # MOVED to directive: collection-repeat-scroll-wrap
        # crw = document.getElementsByClassName('collection-repeat-wrap')
        # return $scope.on._info  if !crw.length 
        # $timeout ()->
        #     angular.element(crw).triggerHandler('scroll.resize');
        #   , 0
        return $scope.on._info   
      addFavorite: (event, item)->
        item.favorite = true
        return item
      addShare: (event, item)->
        confirmPopup = $ionicPopup.confirm {
          title: "Share Photo"
          template: "Are you sure you want to share this photo?"
        }
        confirmPopup.then (res)->
          item.shared = !!res
        return item  
      dontShowHint : (hide)->
        # check config['dont-show-again'] to see if we should hide hint card
        current = $scope.$state.current.name.split('.').pop()
        if hide
          target = ionic.DomUtil.getParentOrSelfWithClass(hide.currentTarget, 'card')
          # TODO: add proper hide animation
          target = angular.element(target).addClass('card-animate').addClass('slide-out-left-hide')
          property = $scope.config['dont-show-again']['top-picks']
          $timeout ()->
              property[current] = true
              target.removeClass('card-animate').removeClass('slide-out-left-hide')
            , 500
           
        return $scope.config['dont-show-again']['top-picks']?[current]
    }  

    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      setFilter(toState)   



      
       

    init = ()->
      $scope.photos_ByDate = TEST_DATA.cameraRoll_byDate
      $scope.moments = otgData.orderMomentsByDescendingKey otgData.parseMomentsFromCameraRollByDate($scope.photos_ByDate), 2
      $scope.photos = otgData.parsePhotosFromMoments $scope.moments
      setFilter( $state.current )
      $scope.on.showInfo(true) if $scope.config['top-picks']?.info

      # add some test data
      TEST_DATA.addSomeFavorites($scope.photos)
      TEST_DATA.addSomeShared($scope.photos)




      # update menu banner
      $scope.menu.top_picks.count = $scope.photos.length

      # add item.height for collection-repeat
      _.each $scope.photos, (e,i,l)->
        e.height = if e.id[-5...-4]<'4' then 400 else 240
        # e.height = 240
        e.src = "http://lorempixel.com/"+(320)+"/"+(e.height)+"?"+e.id
        return

      return

    init()
  ]




