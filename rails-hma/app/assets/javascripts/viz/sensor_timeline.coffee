class window.SensorTimeline extends Timeline
	refresh: ()->
		super()
		this.draw()

	get_minmax: (data, axis)->
		h_max = _.map data, (line)->
			pt = _.max line, (pt)-> return pt[axis]
			return pt[axis]			
		
		h_min = _.map data, (line)->
			pt = _.min line, (pt)-> return pt[axis]	
			return pt[axis]	
		return {
			max: _.max(h_max)
			min: _.min(h_min)
		}
	draw: ()->
		if not this.data then return
		_.each this.ui.getItems({name: "sensor_line"}), (el)-> el.remove()

		scope = this
		timebox = this.ui.children.timebox
		scrubber = this.ui.children.scrubber
		data = this.data
		channels = data.data


		ts = this.ui.range.timestamp
		t_start = this.ui.range.start + ts
		t_end = this.ui.range.end + ts

		lines = _.map channels, (channel, k)->
			filtered_pts = []
			original_pts = []
			_.each channel, (mag, i)->
				t = data.time[i]+ data.timestamp
				if t >= t_start and t <= t_end
					if filtered_pts.length == 0
						filtered_pts.push [t - 0.5, 0]
					filtered_pts.push [t, mag]	
					original_pts.push [t, mag]
				else
					original_pts.push [t, mag]
					return
			return {filtered: filtered_pts, raw: original_pts}
		h = @get_minmax _.pluck(lines, "raw"), 1
		h.range = h.max - h.min
		t = @get_minmax _.pluck(lines, "raw"), 0
	

		plot_start = scrubber.probeTime(t.min).p
		plot_end = scrubber.probeTime(t.max).p

		if plot_start < 0 then plot_start = 0
		if plot_end > 1 then plot_end = 1
		end = (1 - plot_end)
		start = plot_start
		w = 1 - end - start
		
		plot_width = timebox.bounds.width *  w
		if plot_width <= 0 then return

		lines = _.pluck(lines, "filtered")
		lines = _.map lines, (pts, i)->
			line = new paper.Path.Line
				name: "sensor_line"
				parent: scope.ui
				strokeColor: window.channel_colors[i]
				strokeWidth: 1
				segments: pts
				
			line.bringToFront()
			return line

		plot_height = timebox.bounds.height
		lw_max = (_.max lines, (line)-> return line.bounds.width).bounds.width			
		_.each lines, (line)-> line.scaling.x = (plot_width)/lw_max
		_.each lines, (line)-> line.scaling.y = (plot_height - 10)/h.range

		
		pos = scrubber.probeTime(t.min).point
		_.each lines, (line)-> 
			if line.length <= 0 then return
			line.pivot = line.firstSegment.point

			if plot_start <= 0
				line.position = timebox.bounds.leftCenter
			else
				line.position = pos