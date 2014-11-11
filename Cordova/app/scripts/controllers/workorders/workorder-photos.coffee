'use strict'

###*
 # @ngdoc function
 # @name ionBlankApp.controller:WorkorderPhotosCtrl
 # @description
 # # WorkorderPhotosCtrl
 # Controller of the ionBlankApp
###
angular.module('ionBlankApp')
.filter 'workorderPhotoFilter', ()->
  return (input, type='none')->
    switch type
      when 'none' 
        return input
      when 'todo' 
        # match = '2468ACE'   # match last CHAR of UUID
        return _.reduce input, (result, e, i)->
            result.push(e) if e.topPick != false &&  !e.topPick
            return result
          , [] 
      when 'picks'
        return _.reduce input, (result, e, i)->
            result.push(e) if e.topPick == true 
            return result
          , [] 

.directive 'workorderInProgressCard', [
  '$q'
  ($q)->
    self = {
      templateUrl: 'partials/workorders/menu-workorder-snapshot'
      restrict: 'EA'
      scope:{
        order:'=ngModel'
      }
      link: (scope, element, attrs)->
        return
    }
    return self
]

.controller 'WorkorderPhotosCtrl', [
  '$scope', '$rootScope', '$state', '$q', 
  '$ionicSideMenuDelegate', 'otgData', 'otgParse', 
  '$timeout', '$filter', '$window', '$ionicPopup', 'TEST_DATA', 
  ($scope, $rootScope, $state, $q, $ionicSideMenuDelegate, otgData, otgParse, $timeout, $filter, $window, $ionicPopup, TEST_DATA) ->
    $scope.label = {
      title: "Workorder Photos"
      header_card: 
        'app.workorders.photos': 
          header: "Workorder Photos"
          body: "All photos from a customer workorder. Editors must select Top-picks from these photos. All photos must be scanned. "
          footer: ""
        'app.workorders.photos.new':
          header: "Favorites"
          body: "Only photos that are new and have not yet been reviewed."
          footer: ""  
        'app.workorders.photos.top-picks':
          header: "Shared"
          body: "A selection of Top Picks and Favorite Shots as selected by Editors. This is what the client will see."
          footer: ""  
    }

    # $scope.SideMenuSwitcher.leftSide.src = 'partials/workorders/left-side-menu'
    $scope.SideMenuSwitcher.watch['workorder'] = null


    # HACK: directive:workorderInProgressCard is NOT watching updates to
    # SideMenuSwitcher.watch.workorder (parent scope) from promise
    # so force redirect to working 'path', need a $apply() somewhere????
    return $state.transitionTo("app.workorders.all") if true && !$rootScope.workorderColl?


    $scope.getItemHeight = (item, index)->
      # console.log "index="+index+", item.h="+item.height+" === index.h="+$scope.cameraRoll_DATA.photos[index].height+", index.id="+$scope.cameraRoll_DATA.photos[index].id
      h = $scope.filteredPhotos[index].height
      h += 90 if $scope.on.showInfo()
      return h

    # filter photos based on $state.current
    setFilter = (toState)->
      switch toState.name
        when 'app.workorders.photos'
          $scope.filteredPhotos = $filter('workorderPhotoFilter')($scope.photos,'none')
        when 'app.workorders.photos.todo'
          $scope.filteredPhotos = $filter('workorderPhotoFilter')($scope.photos,'todo')
        when 'app.workorders.photos.picks'
          $scope.filteredPhotos = $filter('workorderPhotoFilter')($scope.photos,'picks')
      return    

    # use dot notation for prototypal inheritance in child scopes
    $scope.on  = {
      _info: true
      showInfo: (value=null)->
        return $scope.on._info if value == null 
        revert = $scope.on._info
        if value=='toggle'
          $scope.on._info = !$scope.on._info 
        else if value != null 
          $scope.on._info = value
        $ionicScrollDelegate.$getByHandle('collection-repeat-wrap').resize() if $scope.on._info != revert
        return $scope.on._info     
      notTopPick: (event, item)->
        event.preventDefault();
        revert = item.topPick
        return if revert==false
        item.topPick = false
        coll = $scope.parse_raw.photosColl
        otgParse.savePhotoP(item, coll, 'topPick').then ()->
            $scope.workorderAttr.progress.todo -= 1 if !revert && revert != false
            $scope.workorderAttr.progress.picks -= 1 if revert==true
            return $scope.$apply()
            # don't have to save to Parse yet
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if $state.current.name != 'app.workorders.photos'
          # refresh on reload
          # setFilter( $state.current )

        # scroll to next item()
        return item  
      addTopPick: (event, item)->
        event.preventDefault();
        revert = item.topPick
        return if revert==true
        item.topPick = true
        coll = $scope.parse_raw.photosColl
        otgParse.savePhotoP(item, coll, 'topPick').then ()->
            $scope.workorderAttr.progress.todo -= 1 if !revert && revert != false
            $scope.workorderAttr.progress.picks += 1 if revert==false
            return $scope.$apply()
            # don't have to save to Parse yet
          , (err)->
            item.topPick = revert
            console.warn "item NOT saved, err=" + JSON.stringify err
        # if  $state.current.name != 'app.workorders.photos'
          # refresh on reload
          # setFilter( $state.current )

        # scroll to next item()
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

    $scope.data = {
      cardStyle : {
        width: '100%'
      }
    }

    parse = {
      _fetchWorkorderPhotosP : (options = {})->
        _options = options  # closure
        return otgParse.checkSessionUserP().then otgParse.checkSessionUserRoleP 
        .then ()->
          _options.editor = $rootScope.sessionUser.get('id')
          if _.isEmpty _options.workorder
            return otgParse.getWorkorderByIdP(_options.woid).then (workorder)->
              _options.workorder = workorder
          else 
            $q.when(_options)
        .then ()->
          return otgParse.fetchWorkorderPhotosByWoIdP(_options)
        .then (photosColl)->
          _options.photosColl = photosColl
          $q.when(_options)
        .then (o)->  
          $scope.photos = o.photosColl.toJSON()
          $scope.workorder = o.workorder

          return $q.when(o)  
    }


    $rootScope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams, error)->
      setFilter(toState)   


    init = ()->
      options = {
        woid: $state.params['woid']
      }

      if $rootScope.workorderColl?
        options.workorder = _.findWhere $rootScope.workorderColl.models, { id: options.woid } 

      parse._fetchWorkorderPhotosP(options).then (o)->
        $scope.parse_raw = o

        # add to sideMenu
        $scope.SideMenuSwitcher.watch['workorder'] = $scope.workorderAttr =  $scope.workorder.toJSON()
        window.debug.sms = $scope.SideMenuSwitcher.watch
        window.debug.root = $rootScope

        # add fake height for collecton-repeat on TEST_DATA from lookup
        _.each $scope.photos, (item)->
          item.height = _.findWhere( $scope.cameraRoll_DATA.photos, {id:item.assetId} ).height

        # update work in progress counts
        woProgress = _.reduce $scope.photos, (result, item)->
            result.picks += 1 if item.topPick == true
            result.todo +=1 if !item.topPick && item.topPick != false
            return result
          , {
            todo: 0
            picks: 0 
          }

        $scope.workorder.save({progress: woProgress})

          

        setFilter( $state.current )
        $scope.on.showInfo(true) if $scope.config['workorder.photos']?.info

        # ???: should be able to set width as %, but it doesn't work
        $scope.data.cardStyle.width = Math.min( ($window.innerWidth - 20) , 640 ) + 'px';


      return

    init()
  ]




