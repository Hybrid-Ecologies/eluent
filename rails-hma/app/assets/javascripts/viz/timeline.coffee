#= require_self
#= require viz/code_timeline
#= require viz/sensor_timeline
window.human_time = (t)->
	return moment(t * 1000).format("MM/DD hh:mm:ss")
window.simple_time = (t)->
	return moment(t * 1000).format("hh:mm:ss")
class window.Timeline
	@lines: []
	@load: (video)->
		Timeline.ts = video.raw.timestamp
		$('video').attr('src', video.mp4.url)

	@ts: null	
	load: (channel, data)->
		this.data = data
		this.ui.setTitle channel.toUpperCase()
		this.refresh()
	constructor: (op)->
		op = op or {}
		scope = this
		_.extend this, op
		timeline = new AlignmentGroup
			name: "timeline"
			title: 
				content: op.title or "TIMELINE"
				orientation: 'vertical'
			moveable: false
			padding: 5
			orientation: "vertical"
			video: $('video')[0]
			background: 
				fillColor: "white"
				padding: 5
				radius: 5
				shadowBlur: 5
				shadowColor: new paper.Color(0.9)
			anchor: op.anchor
			range: 
				start: 60 * 0
				end: 60 * 5
			data:
				class: "Timeline"		
			get: (name)-> return this.children[name]
			onMouseDrag: (e)->
				if e.type == "wheel"
					if e.shiftKey
						this.range.end += e.delta.x/2
						this.range.start -= e.delta.x/2
						scope.refresh()
					else
						this.range.start += e.delta.y
						this.range.end += e.delta.y
						scope.refresh()
						
			addEnding: ()->
				d = $('video')[0].duration + timeline.range.timestamp
				timebox = this.children.timebox
				
				# end_buffer
				if end_buffer = this.children.end_buffer then end_buffer.remove()
				end = timeline.range.timestamp + timeline.range.end
				if d < end
					dim = this.children.scrubber.probeTime(d)
					width = _.min([dim.total - dim.offset, timebox.bounds.width])
					buffer = new paper.Path.Rectangle
						parent: this
						name: "end_buffer"
						size: [width, timebox.bounds.height]
						fillColor: new paper.Color(0)
						opacity: 0.5
					buffer.pivot = buffer.bounds.rightCenter
					buffer.position = timebox.bounds.rightCenter

				if start_buffer = this.children.start_buffer then start_buffer.remove()
				
				ts = timeline.range.timestamp
				if timeline.range.start < 0
					dim = this.children.scrubber.probeTime(ts)
					width = _.min([dim.offset, timebox.bounds.width])
					buffer = new paper.Path.Rectangle
						parent: this
						name: "start_buffer"
						size: [width, timebox.bounds.height]
						fillColor: new paper.Color(0)
						opacity: 0.5
					buffer.pivot = buffer.bounds.leftCenter
					buffer.position = timebox.bounds.leftCenter


		timeline.init()
		this.ui = timeline
		@addPlot(timeline)


		@addControlUI(timeline)
		@bindVideoEvents(timeline)
		
		Timeline.lines.push this

	refresh: ()->
		this.ui.addEnding()
		this.addTimeLabels()
	make_label: (content)->
		scrubber = this.ui.get("scrubber")
		_.each this.ui.getItems({name: "t_label"}), (el)-> el.remove()
		t_label = new Group
			name: "t_label"
			parent: this.ui
			ui: true
			onMouseDown: (e)-> this.bringToFront()
		label = new paper.PointText
			parent: t_label
			content: content
			fillColor: new paper.Color(0.6)
			fontFamily: 'Avenir'
			fontSize: 12
			fontWeight: "normal"
			justification: 'center'
		bg = new paper.Path.Rectangle
			parent: t_label
			rectangle: t_label.bounds.expand(5, 3)
			fillColor: "white"
			radius: 2
			shadowColor: new paper.Color(0.4)
			shadowBlur: 2
		bg.sendToBack()
		t_label.pivot = t_label.bounds.bottomCenter.add(new paper.Point(0, 5))
		t_label.position = scrubber.bounds.topCenter	
	makeTimeLabel: ()->
		ms = this.ui.range.timestamp
		scrubber = this.ui.get("scrubber")
		t = scrubber.getTime()
		t = moment((ms + t) * 1000).format("hh:mm:ss A")
		@make_label(t)
	addPlot: (timeline)->
		scope = this
		timebox = new paper.Path.Rectangle
			size: [600, 60]
			fillColor: "#F5F5F5"
			strokeColor: "#CACACA"
			video: $('video')[0]
			cueThreshold: 5
			name: "timebox"
			get: (name)-> return this.children[name]
			getP: (name)-> return this.parent.children[name]
			clearUI: ()-> 
				ui = this.parent.getItems {ui: true}
				_.each ui, (el)-> el.remove()
			addCue: (e)->
				timebar = @getP("timebar")
				dis = e.point.x - this.down.x
				dir = dis > 0
				dis = Math.abs(dis)
				if dis > this.cueThreshold
					cue = new paper.Path.Rectangle
						parent: this.parent
						name: "cue"
						size: [dis, this.bounds.height * 0.9]
						opacity: 0.5
						fillColor: "#00A8E1"
						radius: 2
						ui: true
					cue.pivot = if dir > 0 then cue.bounds.leftCenter else cue.bounds.rightCenter
					cue.position = timebar.getNearestPoint(this.down)
					cue.pivot = cue.bounds.leftCenter
			updateScrubber: (pt)->
				scrubber = @getP("scrubber")
				scrubber.setPos(pt.x)
				scope.makeTimeLabel()
			
			onMouseDown: (e)->
				@clearUI()
				this.p = new paper.Path
					strokeColor: "#00A8E1"
					strokeWidth: 1
					segments: [e.point]
				t = this.updateScrubber(e.point)
				this.down = e.point
				e.stopPropagation()
			onMouseDrag: (e)->
				this.p.addSegment(e)
				@clearUI()
				@updateScrubber(e.point)
				if e.modifiers.shift
					@addCue(e)
				e.stopPropagation()
			onMouseUp: (e)->
				this.p.remove()
				if cue = @getP("cue")
					scrub = this.parent.children.scrubber
					scrub.setPos(cue.position.x+1)
					@updateScrubber(cue.position)
				e.stopPropagation()

		timeline.pushItem timebox
		timeline.addEnding()
		
		timebar = new paper.Path.Line
			name: "timebar"
			parent: timeline
			to: timebox.bounds.rightCenter
			from: timebox.bounds.leftCenter
			strokeColor: "#CACACA"
			strokeWidth: 1
			visible: true

		scrub = new paper.Path.Line
			parent: timeline
			name: "scrubber"
			from: timebox.bounds.topLeft
			to: timebox.bounds.bottomLeft
			strokeColor: "#00A8E1"
			strokeWidth: 2
			setPos: (x)->
				this.position.x = x
				$('video')[0].currentTime = this.getTime()
			getPos: ()-> return this.bounds.center
			getOffset: ()->
				timebar = this.parent.children.timebar
				np = timebar.getNearestPoint(@getPos())
				offset = timebar.getOffsetOf(np)
				return offset
			getP: ()->
				timebar = this.parent.children.timebar
				return @getOffset() / timebar.length
			getTime: ()->
				range = (this.parent.range.end - this.parent.range.start)
				return this.parent.range.start + range * @getP()

			probeTime: (t)->
				t = t - this.parent.range.timestamp
				timebar = this.parent.children.timebar
				range = (this.parent.range.end - this.parent.range.start)
				p = (t - this.parent.range.start) / range
				return {
					point: timebar.getPointAt(p * timebar.length) 
					p: p
					offset: p * timebar.length
					total: timebar.length
				}
			gotoTime: (t)->
				timebar = this.parent.children.timebar
				timebox = this.parent.children.timebox
				range = (this.parent.range.end - this.parent.range.start)
				if t > this.parent.range.end or t < this.parent.range.start
					# Timeline needs update;
					# Need to update the range of the timeline and redraw labels
					return
				else
					p = (t - this.parent.range.start) / range
					np = timebar.getPointAt(p * timebar.length)
					this.position.x = np.x
				scope.makeTimeLabel()

		textbox = new paper.Path.Rectangle
			parent: timeline
			name: "textbox"
			size: [timebox.bounds.width, 25]
			strokeColor: "#CACACA"
			strokeWidth: 1
			visible: false
		textbox.pivot = textbox.bounds.topCenter
		textbox.position = timebox.bounds.bottomCenter

		
		textline = new paper.Path.Line
			parent: timeline
			name: "textline"
			from: textbox.bounds.leftCenter
			to: textbox.bounds.rightCenter
			strokeColor: "#CACACA"
			strokeWidth: 1
			visible: false
	addTimeLabels: ()->
		# time label container
		timeline = this.ui
		timebox = timeline.children.timebox
		textline = timeline.children.textline
		textbox = timeline.children.textbox

		_.each timeline.getItems({name: "timelabel"}), (t)-> t.remove()

		ms = this.ui.range.timestamp
		# console.log "TS", moment(ms * 1000).format("MM/DD/YY hh:mm A")
			
		start = timeline.range.start
		end = timeline.range.end
		range = end-start
		text = _.range(0, range, Math.ceil(range/5)) #10 labels max

		_.each text, (t)->
			p = t / range
			t = t + start
			time = start + text
			tt = new paper.PointText
				parent: timeline
				name: "timelabel"
				content: moment((ms + t) * 1000).format("hh:mm:ss A")
				fillColor: new paper.Color("#CACACA")
				fontFamily: 'Avenir'
				fontSize: 12
				fontWeight: "normal"
				justification: 'center'
			tt.pivot = tt.bounds.center
			tt.position = textline.getPointAt(p * textline.length)
	addControlUI: (timeline)->
		if this.controls.rate
			buttons = new AlignmentGroup
				parent: timeline
				name: "buttons"
				padding: 3
				orientation: "horizontal"
				settings:
					step: 0.5
					max: 9
					min: 0.5
				anchor: 
					pivot: "bottomRight"
					position: timeline.bounds.topRight
					offset: new paper.Point(0, -5)

			buttons.pushItem new LabelGroup
				orientation: "horizontal"
				padding: 1
				text: "SPEED +"
				button: 
					fillColor: new paper.Color(0.9)
				onMouseDown: (e)->
					$('video')[0].playbackRate += this.parent.settings.step
					if $('video')[0].playbackRate > this.parent.settings.max then $('video')[0].playbackRate = this.parent.settings.max
					if $('video')[0].playbackRate < this.parent.settings.min then $('video')[0].playbackRate = this.parent.settings.min
					e.stopPropagation()	
			rate = new LabelGroup
				orientation: "horizontal"
				padding: 1
				text: "1.0"
			buttons.pushItem rate
			buttons.pushItem new LabelGroup
				orientation: "horizontal"
				padding: 1
				text: "SPEED -"
				button: 
					fillColor: new paper.Color(0.9)
				onMouseDown: (e)->
					$('video')[0].playbackRate -= this.parent.settings.step
					if $('video')[0].playbackRate > this.parent.settings.max then $('video')[0].playbackRate = this.parent.settings.max
					if $('video')[0].playbackRate < this.parent.settings.min then $('video')[0].playbackRate = this.parent.settings.min
					e.stopPropagation()	
		
			$('video').on "ratechange", ()->
				rate.updateLabel this.playbackRate.toFixed(1)
				
	bindVideoEvents: (timeline)->
		$('video').on 'timeupdate', (e)->
			scrub = timeline.children.scrubber
			scrub.gotoTime(this.currentTime)
			cue = timeline.children.cue
			if cue and not scrub.intersects(cue)
				this.pause()
				scrub.position.x = cue.position.x+1
				this.currentTime = scrub.getTime()
