
window.adjustData = (data, t, Fs, callback)->
	$.getJSON $("#metadata").attr('src'), (metadata)->
		start = metadata.session_start - t
		end = metadata.session_end - t    
		
		t0 = start * Fs 
		t0 = if start > 0 then start * Fs  else 0
		tf = if end < data.length then  end * Fs - 1 else data.length
		t0 = parseInt(t0)
		tf = parseInt(tf)
		data = data.slice(t0, tf)
		callback(data)

class window.Plot extends paper.Group
		init: (style)->
			this.name = "plotarea"
			this.pivot = this.bounds.leftCenter
			anchor = new paper.Path.Rectangle
				parent: this
				name: "anchor"
				size: [2, paper.plot.height * 0.9]
				fillColor: '#333'
				

			anchor.pivot = anchor.bounds.rightCenter
			this.anchor = anchor
			this.set style
			this.set
				resolveAndPlay: (e)->
					bg = this.children.bg
					p = (e.point.x - bg.bounds.leftCenter.x) / bg.bounds.width
					this.goTo(p)
					_.each $("video"), (v)-> 
						v.currentTime = p * v.duration
						# v.play()
				onMouseDown: (e)->
					this.resolveAndPlay(e)
					e.preventDefault()
					e.stopPropagation()
				onMouseDrag: (e)->
					this.resolveAndPlay(e)
					e.preventDefault()
					e.stopPropagation()
				onMouseUp: (e)->
					this.resolveAndPlay(e)
					e.preventDefault()
					e.stopPropagation()
		goTo: (p)->
			if this.children.scrubber
				this.children.scrubber.goTo(p)

		add_scrubber: ()->
			scope = this
			scrubber = new paper.Group
				name: "scrubber"
				parent: this
				goTo: (p)->
					this.position.x = this.parent.children.bg.bounds.width * p
					this.position.x -= this.bounds.width / 2
			
			line = new paper.Path.Line
				parent: scrubber
				strokeColor: "#00A8E1"
				strokeWidth: 2
				segments: [paper.view.bounds.topLeft, paper.view.bounds.bottomLeft]
			
			a = paper.view.bounds.topLeft.clone()
			b = a.clone()
			c = b.clone()
			a.y = a.y + 8
			b.x = b.x - 6
			c.x = c.x + 6

			new paper.Path
				parent: scrubber
				segments: [b, c, a]
				fillColor: "#00A8E1"
				closed: true
			scrubber.pivot = scrubber.bounds.center
			_.delay (()->
				bg = new paper.Path.Rectangle
					parent: scope
					name: "bg"
					rectangle: scope.bounds
					# fillColor: "orange"
				bg.scaling.y = 0.9
				bg.sendToBack()
			), 1000,

		line: (op)->
			scope = this
			$.getJSON(op.src, (contents)->	
				if contents.sampling_rate
					adjustData contents.data, contents.timestamp, contents.sampling_rate, (data)->
						if op.src.includes('smna')
							console.log "SMNA"
						scope._line(data, op)
				else
					scope._line(contents.data.y, op)
				scope.add_scrubber()
			).fail ()->
				scope.parent.style.fillColor = "gray"
				bg = new paper.Path.Rectangle
					parent: scope
					name: "bg"
					rectangle: paper.view.bounds
					fillColor: "orange"
				bg.scaling.y = 0.9
				bg.sendToBack()
			
		_line: (data, op)->
			
			scope = this
			anchor = this.children.anchor
			
			pts = _.map data, (y, t)->
				return new paper.Point(t/data.length * 400, y)

			path = new paper.Path
				parent: this
				name: 'line'
				strokeColor: "#111"
				strokeWidth: 1
				segments: pts

			if op.style
				path.set op.style

			path.position = paper.view.center
			path.scaling.y = -1 * paper.view.bounds.height * 0.8/ path.bounds.height
			path.scaling.x = paper.view.bounds.width / path.bounds.width
	
			# baseline = new paper.Path
			# 	name: "baseline"
			# 	parent: this
			# 	strokeColor: "#DDD"
			# 	strokeWidth: 1
			# 	segments: [this.bounds.leftCenter, this.bounds.rightCenter]


		load_cues: ()->
			scope = this
			anchor = this.children.anchor

			
			_.each cues, (c)->
				if c.code != "0" 
					r = new paper.Path.Rectangle
						code: parseInt(c.code)
						parent: scope
						size: [10 * c.width, paper.plot.height * 0.9]
						fillColor: c.color
					r.pivot = r.bounds.leftCenter
					r.position = anchor.position
					r.pivot = r.bounds.rightCenter
					anchor = r
			this.scaling.x = paper.view.bounds.width/this.bounds.width
			this.pivot = this.bounds.leftCenter
			this.position = paper.view.bounds.leftCenter
			scope.add_scrubber()


class window.PlotManager
	test_trigger: ()->
		event = jQuery.Event("scrubupdate")
		event.p = 0.5;
		$(".paper-plot").trigger(event)

	constructor: ()->
		scope = this
		this.plots = {}
		$(".paper-plot").on "load", (e)->

			container = $(this)
			src = container.attr('src')
			color = container.attr('color')
			

			paper =  makePlot
				parent: container
				height: 50

			container.on "scrubupdate", (e)->
				area = paper.project.getItems({name: "plotarea"})
				if area.length > 0
					area[0].goTo(e.p)

			
			plot = new Plot()
			
			plot.init
				fillColor: "white"

			if src
				plot.line
					src: src
					style:
						strokeColor: color
					container: container
				scope.plots[src] = plot
			else
				# console.log "loading cues", cues
				plot.load_cues
					cues: cues
				scope.plots["chromatogram"] = plot

			