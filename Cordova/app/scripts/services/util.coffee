'use strict'

###*
 # @ngdoc service
 # @name ionBlankApp.util
 # @description
 # # utility services
###


angular.module 'snappi.util', []
.service 'snappiTemplate', [
	'$q', '$http', '$templateCache'
	($q, $http, $templateCache)->
		self = this
		# templateUrl same as directive, do NOT use SCRIPT tags
		this.load = (templateUrl)->
			$http.get(templateUrl, { cache: $templateCache})
			.then (result)->
				console.log 'HTML Template loaded, src=', templateUrl
		return

]