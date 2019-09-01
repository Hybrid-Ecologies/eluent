class window.DataGrabber 
	constructor: (op)->
		@acquireManifest op.success
	mapEach: (root, mapFn)->
		scope = this
		root = mapFn(root)
		_.map root, (data, root)-> 
			if _.isObject(data) then scope.mapEach(data, mapFn)
	resolveJSON: (manifest)->
		# RESOLVE JSON FILES
		return @mapEach manifest, (obj)->
			if not obj.url then return obj
			filetype = obj.url.split('.').slice(-1)[0] 
			switch filetype
				when "json"
					return _.extend obj, 
						data: $.ajax({dataType: "json", url: obj.url, async: false}).responseJSON
				else
					return obj
	cleanSchema: (manifest)->
		# ZIP adjustment
		_.each manifest, (data, user)->
			if data.iron.imu
				imu_data = _.mapObject data.iron.imu.various.data, (data, channel)->
					_.extend data,
						type: "sensor_plot"

				manifest[user].iron.imu = imu_data
	processData: (manifest)->
		# EXTRACT AUTHORS
		actors = _.values manifest
		actors = _.pluck actors, "env"
		actors = _.flatten _.pluck actors, "video"
		actors = _.flatten _.pluck actors, "codes"
		actors = _.flatten _.pluck actors, "data"
		actors = _.unique _.pluck actors, "actor"
		actors = _.object _.map actors, (a, i)-> 
			[a, color_scheme[i]]
		
		# ATTACH COLOR
		_.each manifest, (data, user)->
			manifest[user].env.video.codes.data = _.map data.env.video.codes.data, (code)->
				_.extend code, 
					color: actors[code.actor]

		return actors

	acquireManifest: (callbackFn)->
		scope = this
		rtn = $.getJSON data_source, (manifest)-> 
			window.manifest = scope.resolveJSON(manifest)
			scope.cleanSchema(manifest)
			actors = scope.processData(manifest)

			callbackFn.apply scope, [
				activity: manifest
				actors: actors
			]