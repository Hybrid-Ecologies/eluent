class window.CodeTimeline extends Timeline
	refresh: ()->
		super()
		this.draw()

	draw: ()->
		console.log "CODE", this.data
		scope = this
		_.each this.ui.getItems({name: "tag"}), (el)-> el.remove()
		if not this.data then return
		scrubber = this.ui.get("scrubber")
		tracks = 3
		H = scrubber.bounds.height
		h =  H/tracks
		track_offset = h/tracks
		timebox = this.ui.get("timebox")

		tags = []
		
		t_start = this.ui.range.start + this.ui.range.timestamp
		t_end = this.ui.range.end + this.ui.range.timestamp
		
		ts = this.data.timestamp
		
		codes = _.map this.data.data, (code)->
			s = ts + code.start
			e = ts + code.end
			console.log code
			if s > t_start and e < t_end
				_.extend _.clone(code), 
					draw: true
					start: s
					end: e
			else if s < t_start
				if t_start >= e then return {draw: false}
				_.extend _.clone(code), 
					draw: true
					start: t_start
					end: e
			else if e > t_end
				if s >= t_end then return {draw: false}
				_.extend _.clone(code), 
					draw: true
					start: s
					end: t_end
			else
				_.extend _.clone(code), 
					draw: false

		
		_.each codes, (code, i)->
			if not code.draw then return
			s = scrubber.probeTime(code.start)
			e = scrubber.probeTime(code.end)
			if not e.point then return
			if not s.point then return
			dis = e.point.x - s.point.x

			track_iter = 0
			track_id = i % tracks
			s.point.y -= H/2

			while track_iter < tracks
				
				s.point.y += (track_id * h) + (h/2)
				all_clear = _.every tags, (t)->
					return not t.contains(s.point)
				if all_clear
					break
				track_iter++
				
				if track_iter >= tracks	
					break
				
				s.point.y -= (track_id * h) + (h/2)
				
				track_id += 1
				if track_id == tracks then track_id = 0 
			if not code.color
				code.color = color_scheme[code.codes[0]]

			dark = new paper.Color(code.color)
			dark.brightness -= 0.3
			c = new paper.Path.Rectangle
				parent: scope.ui
				name: "tag"
				data: 
					actor: code.actor
					tags: code.codes
				size: [dis, h * 0.9]
				opacity: 1
				fillColor: code.color
				radius: 2
				strokeColor: dark
				opacity: 0.5
				onMouseDown: (e)-> 
					# console.log i
					timebox.onMouseDown(e)
				onMouseDrag: (e)-> timebox.onMouseDrag(e)
				onMouseUp: (e)-> timebox.onMouseUp(e)
			c.pivot = c.bounds.leftCenter 
			c.position = s.point
			tags.push c

	makeTimeLabel: ()->
		scrubber = this.ui.get("scrubber")
		tags = this.ui.getItems({name: "tag"})
		tags = _.filter tags, (t)-> scrubber.intersects(t)
		tags = _.map tags, (t)-> 
			t.data.actor + ": " + t.data.tags.join("→ ")
		t = scrubber.getTime()

		ms = this.ui.range.timestamp
		t = moment((ms + t) * 1000).format("hh:mm:ss A")
		tags.push t
		@make_label(tags.join('\n'))
		

window.channel_colors = ["red", "green", "blue"]
