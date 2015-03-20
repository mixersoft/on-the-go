'use strict'

###*
 # @ngdoc service
 # @name ionBlankApp.localNotification
 # @description
 # wrapper for localNotification plugin, adds badges, notifications to iOS notification panel
###


angular.module 'snappi.localNotification', ['ionic', 'ngStorage', 'snappi.util']
.factory( 'localNotificationPluginSvc', [ 
  '$rootScope', '$location'
  '$timeout', '$q'
  '$ionicPlatform'
  'notifyService'
  'deviceReady'
  ($rootScope, $location, $timeout, $q, $ionicPlatform, notify, deviceReady)->
    CFG = {
      debug: false || window.location.hostname == 'localhost' 
      templates: [
          {
            id: 101
            title: "Bon Voyage!"
            message: "You have an order for a trip that begins today! Please make sure the Uploader is enabled."
            target: "app.uploader"
            schedule: null
          }
        ]      
    }
    _isValidDate = (date)->
      return true if _.isDate(date) && _.isNaN(date.getTime())==false
      return false

    # wrapper class for working with the localNotification plugin
    # includes 'emulated' mode for desktop browser testing without the plugin
    class LocalNotify 
      constructor: (options)->
        self = this
        # self._notify = self.loadPlugin()
        deviceReady.waitP().then ()->
          self.loadPlugin()
          window.debug.notifyPlugin = self
          window.debug.notifyPlugin.testMsg = CFG.templates[0]
        return

      init: ()->
        this.loadPlugin() if !this.isReady()

      isReady: ()->
        return !!this._notify

      loadPlugin: ()->
        self = this
        if window.plugin?.notification?.local? 
          self._notify = window.plugin.notification.local
          self._notify.setDefaults({ autoCancel: true })
          self._notify.on("schedule" , self.handleSchedule, self )
          self._notify.on("trigger" , self.handleTrigger, self)
          self._notify.on("click" , self.handleClick, self)
          self._notify.on("cancel" , self.oncancel, self)
          # console.log "####### LocalNotification handlers added ##################"
          # notify.alert "localNotify, callbacks added", "success"
          # send App to background event
          if deviceReady.device().isDevice
            $ionicPlatform.on 'resume', ()->
                return self.checkTriggered.apply(self)
              , self
              # check for triggered notifications



        else  
          # notify.alert "LocalNotification plugin is NOT available" if CFG.debug
          self._notify = false
        return self._notify

      showDefaults: ()->
        return false if !this._notify
        notify.alert JSON.stringify(this._notify.getDefaults()), "warning", 40000


      addByDelay: (delay=5, notification={})->
        return if deviceReady.device().isBrowser && CFG.debug == false
        now = new Date().getTime()
        reminderDate = new Date( now + delay*1000)
        this.addByDate reminderDate, notification

      # @param reminderDate Date
      # NOTE: if 'repeatSchedule' is set, reminderDate will be modified to fit notification.repeatSchedule, only time component is used
      addByDate: (reminderDate, notification={})->
        try
          # avoid circular references because we will serialize notification
          reminderDate = new Date(reminderDate) if _.isDate(reminderDate) == false
          if !_isValidDate(reminderDate)
            throw "ERROR: reminderDate is not a valid date string, reminderDate="+reminderDate

          # use 'repeatSchedule' instead of 'every' to reschedule
          if notification['repeatSchedule'] && _.isObject(notification['repeatSchedule'])
            reminderDate = this._getDateFromRepeat(reminderDate, notification['repeatSchedule'])
            if reminderDate == false
              notify.message "You must select at least one day of the week for this reminder."
              return false

          now = new Date()
          if now > reminderDate
            notify.message "You are setting a reminder for a time in the past"
            return false

          reminder = {
            id: notification['id'] || now.getTime()   # seems to crash on id:0 
            title: notification['title'] || null
            text: notification['message'] || null
            every: null # in minutes, or ['second', 'minute', 'hour', 'day', 'week', 'month', 'year']
            at: reminderDate # date or unixtime
            badge: notification['badge'] || 0
            sound: null # uri
            data:
              target: notification['target'] || null
              repeatSchedule: notification['repeatSchedule'] || null # DayOfWeek to re-schedule
          }
          # console.log "*** addByDate reminder="+JSON.stringify reminder

          if deviceReady.device().isDevice
            this._notify.schedule( reminder )
            # console.log "localNotify.add()  AFTER message="+JSON.stringify( reminder )
            return reminder['at'] if !CFG.debug

          ### 
          # CFG.debug only
          ###
          delay = Math.round((reminderDate.getTime() - now.getTime())/1000)
          if deviceReady.device().isBrowser && CFG.debug # not using LocalNotification plugin
            reminder['message'] = "EMULATED: "+reminder['message']
            notify.alert "localNotification EMULATED, delay="+delay
            this.fakeNotify(delay, reminder)

          if delay < 60
            notify.message({
              title: "A reminder was set to fire in "+ delay + " seconds"
              message: "To see the notification, press the 'Home' button and close this app." 
              })
          else 
            nextReminder = 
              if _.isDate(reminder['at']) 
              then reminder['at']
              else new Date(reminder['at']) 
            # console.log " LocalNotification plugin set, date="+ reminder['at'] + ", nextReminder.calendar()=" + nextReminder.calendar()
            notify.message( {
                title: "A Reminder was Set"
                message: "Your next reminder will be at " + nextReminder.toJSON() + "."
              })
                
          # console.log "addByDate COMPLETE"  
          return reminder['at']
        catch error
          msg = "EXCEPTION: addByDate(), error="+JSON.stringify error, null, 2
          # console.log msg
          notify.alert msg, "danger", 600000
    
      # @param except string or array of Strings
      cancel : (ids)=>
        return if !this.isReady()
        return this._notify.cancelAll() if ids=='all' 
        return this._notify.cancel ids, ()->
          return console.log "notification cancelled", ids

      clear : (ids)=>
        return if !this.isReady()
        return this._notify.clearAll() if ids=='all' 
        return this._notify.clear ids, ()->
          return console.log "notification CLEARED", ids
        ## see also: 
        this._notify.getTriggeredIds (ids)->
            return this._notify.clear(ids);
          , this


      # @param date Date object or Date.toJSON()
      #   schedule Object or String, 
      #     Object: example { "1": true, "2": true, "3": true, "4": true, "5": true,  "6": true,  "7": true }
      #   String: 'daily', 'weekly', etc, see LocalNotification plugin docs
      # @return Date object or false if repeat == object and no days of week are enabled
      _getDateFromRepeat : (date, schedule=null)->
        reminder = new Date(date) # parse date with moment.js
        if !_isValidDate(reminder)
          throw "ERROR: _getDateFromRepeat(), date is not a valid date string, date="+date

        reminderTime = reminder.getTime()
        now = new Date()

        if _.isObject( schedule )
          # check day of week
          dayOfWeek = reminder.day()
          nextDayOfWeek = _.reduce schedule, (result, set, day)->
              if set
                day = parseInt(day)
                # 
                day += 7 if day<dayOfWeek
                day += 7 if day==dayOfWeek && reminder < now
                result = if result!=false then Math.min(result, day) else day
              return result
            , false
          return false if nextDayOfWeek == 0
          return reminder.day(nextDayOfWeek).toDate() 

        switch schedule
          when 'weekly'
            delay = 2600 * 24 * 7
          when 'daily'
            delay = 3600 * 24
            # delay = 10
          else
            delay = 10
        return new Date( reminderTime + delay*1000)
                
      # @params options Object
      #   options.schedule Object or string, 
      # options.date Date.toJSON()
      _setRepeat : (notification)->
        # notification = JSON.parse(notification) if _.isString(notification)
        if !_.isEmpty(notification.data['repeatSchedule'])

          # get next random message for Notification Center 
          message = this.getNotificationMessage()
          message['repeatSchedule'] = notification.data['repeatSchedule']  # copy schedule from lastReminder
          # set new reminder
          # note addByDate will get nextReminderDate from _getDateFromRepeat()
          nextReminderDate = this.addByDate( notification['at'], message)
          return nextReminderDate
        else return false

      getNotificationMessage : ()->
        # also defined in actionService, but wanted to avoid circular dependency
        # TODO: notification.data.target is used to route, message is set by route
        return _.sample CFG.templates 

      ###
      # @params notification, from notification.schedule()
      # @params string ['foreground', 'background']
      ###
      handleNotification : (notification, state)->
        # console.log "*** handleNotification(), options=" + JSON.stringify options, null, 2 
        # state=background
        try 
          # notify.alert "onClick state="+state+", json="+json, "success", 60000
          notification = notification
          if notification.id
            localNotify.clear(notification.id) 
          else
            localNotify.clear('all') 
          # console.log " %%%% CONFIRM same as json, notification=" + JSON.stringify notification, null, 2

          notification['message'] = notification['text'] # for notify.alert/message()
          notification.data = JSON.parse(notification.data) if _.isString notification.data 

          repeating = this._setRepeat(notification)
          if repeating
            # notification.data.target controller will set the actual notify.message()
            # make sure it matches notification.message, as shown in Notification Center
            notify.alert "setting NEXT notification for " + repeating, "success", 60000
          $rootScope.$broadcast('localNotification.received', notification)

          # show notification
          notify.message(notification)

          if notification.data.target?
            if notification.data.target[0...4] == 'app.'
              $rootScope.$state.transitionTo( notification.data.target ) 
            else
              $location.path(notification.data.target)


        catch error
          msg = "EXCEPTION: localNotify.handleClick(), error="+JSON.stringify error, null, 2
          # console.log msg
          notify.alert msg, "danger", 600000

        return true     

      # @params state = [foreground | background]
      handleSchedule :(notification,state)=>
        return true 

      # resume sequence of events - from trigger of notification in foreground 
      # onlick -> wakeApp -> resumeApp
      handleTrigger :(notification,state)=>
        # console.log "*** 2 ***** onTRIGGER state="+state+", json="+json 
        this.handleNotification(notification, state)
        return true

      checkTriggered : ()->
        self = this
        self._notify.getAllTriggered (notifications)->
            console.log 'triggered', notifications
            _.each notifications, (notification)->
              self.handleNotification(notification, 'background')
              return
          , this


      # resume sequence of events - from click on item in iOS Notification Center 
      # onlick -> wakeApp -> resumeApp
      # NOTE: using resumeApp to call handleClick from App icon, vs Notification Center
      handleClick :(notification,state)=>
        # console.log "*** 3 ***** onClick state="+state+", json="+json 
        this.handleNotification(notification, state)
        return true


      oncancel :(notification,state)=>
        # console.log "*** 4 ***** onCancel state="+state+", json="+json 
        return true


      # for testing in browser WITHOUT plugin
      fakeNotify: (delay, notification)=>
        state = 'background'
        _getState = (delay)->
          return state if `delay==null`
          return state = if _isLongSleep(delay) then 'background' else 'foreground'

        _isLongSleep = (sleep)->
          # use 4 sec just for fakeNotify testing
          LONG_SLEEP = 4 
          return sleep > LONG_SLEEP
        
        # FAKE notification emulating cordova pause/resume in browser
        # expection attrs: {event:, pauseDuration:, notification:{}}
        _handleResumeOrLocalNotify = (o)->
          # notify.alert "fakeNotify: resuming with o="+JSON.stringify o
          wasAlreadyAwake = _getState(o.pauseDuration) == 'foreground'

          if wasAlreadyAwake
            # just show notification as alert, do not navigate
            context =  "<br /><p>(Pretend this notification fired while the app was in foreground.)</p>" 
            o.notification['text'] += context
            # notify.alert "LocalNotify fired when already awake", "warning"
            type = if wasAlreadyAwake then "info" else "success"
            localNotify.handleNotification( o.notification, state)
            # notify.message(o.notification, type)
          
          else 
            # resume/localNotify from LongSleep should navigate to notification target, 
            #     i.e. active challenge, moment, or photo of the day

            # pick a random challenge and activate
            # notify.alert "LocalNotify RESUME detected, pauseDuration=" + o.pauseDuration, "success"
            if wasAlreadyAwake
              context =  "<br /><p>(Pretend this notification fired while the app was already in foreground.)</p>" 
            else 
              context =  "<br /><p><b>(Pretend you got here after clicking from the Notification Center.)</b><p>" 
            o.notification['text'] += context 
            type = if wasAlreadyAwake then "info" else "success"
            localNotify.handleNotification( o.notification, state)
            # notify.message(o.notification, type, 20000)
          return

        $timeout ()->
            return _handleResumeOrLocalNotify( {
              event: "FAKE LocalNotify"
              pauseDuration: delay
              notification: notification
            })
          , delay*1000
        notify.message({message: "FAKE LocalNotify set to fire, delay="+delay}, "warning", 2000)
        return  


    localNotify = new LocalNotify()
    return  localNotify
    #
    # end Class Notify
    #
]   
)