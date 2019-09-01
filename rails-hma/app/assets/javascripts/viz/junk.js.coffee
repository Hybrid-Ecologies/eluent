
class window.WindowGroup extends AlignmentGroup
	init: ()->
		@ui = {}
		@ui.clipped = new paper.Group
			parent: this
			name: "clipped"

		@makePane()
		@makeTitle()
		@configureWindow()
	get: (name)-> return @ui[name]
	pushItem: (obj)->
		this.get("pane").pushItem(obj)
		
		@reposition()
		@clipWindow()
		@makeTitle()
	configureWindow: ()->
		if this.moveable
			this.set
				onMouseDown: (e)->
					this.bringToFront()
				onMouseDrag: (e)->
					previous = this.position.clone()
					this.translate e.delta
					if not paper.view.bounds.contains(this.bounds)
						this.position = previous
					e.stopPropagation()		
	clipWindow: ()->
		if this.get("clip") then this.get("clip").remove()
		if this.get("shade") then this.get("shade").remove()
		
		r = this.bounds.expand(0)
		
		if this.pane.max_height and r.height > this.pane.max_height
			r.height = this.pane.max_height
		if this.pane.max_width and r.width > this.pane.max_width
			r.width = this.pane.max_width

		@ui.clip = new paper.Path.Rectangle
			parent: this.get("clipped")
			name: "clip"
			rectangle: r
			radius: 3
			strokeWidth: 1
			strokeColor: "#00A8E1"
			clipMask: true
			onMouseDown: (e)->
				console.log this.parent.parent.name
				this.selected = true
			onMouseUp: (e)->
				this.selected = false
		@makeScroll()

		@ui.shade = new paper.Path.Rectangle
			parent: this
			name: "shade"
			rectangle: @ui.clip.bounds.expand(0)
			fillColor: 'purple'
			shadowColor: new paper.Color(0.3, 0.4)
			shadowBlur: 5
			radius: 3
			strokeColor: "#CACACA"
			strokeWidth: 1
			shadowOffset: new paper.Point(2, 2)
		@ui.shade.sendToBack()		
	makePane: ()->
		@ui.pane = new AlignmentGroup _.extend this.pane, 
			parent: this.get("clipped")
			name: "pane"
			background: 
				padding: [15, 30]
				fillColor: "yellow"
	makeTitle: ()->
		scope = this
		if not this.title then return 
		
		bg = @get('clipped')
		if this.get("title_bar") then this.get("title_bar").remove()

		title = new paper.Group
			parent: this.get("clipped")
			name: "title_bar"
			data: 
				ui: true
		

		# BACKGROUND 
		t_bg = new paper.Path.Rectangle
			parent: title
			name: "title_bg"
			size: [bg.bounds.width, 15]
			fillColor: new paper.Color(0.8)
			strokeWidth: 1
			strokeColor: "#CACACA"
			
		title.pivot = title.bounds.topCenter
		title.position = bg.bounds.topCenter
		
		
		# # TEXT
		ops = 
			name: "title"
			parent: title
			content: ""
			fillColor: 'black'
			fontFamily: 'Avenir'
			fontSize: 8
			fontWeight: "bold"
			justification: 'left'
			
		ops = _.extend ops, this.title
		
		t = new paper.PointText ops
		t.pivot = t.bounds.center
		t.position = t_bg.bounds.center
		
		if this.title.buttons
			minimizeButton = new paper.Path.Circle
				name: "minimize"
				fillColor: "#D8D8D8"
				strokeColor: "#CACACA"
				baseColor: new paper.Color "#24C339"
				strokeWidth: 2
				radius: title.bounds.height * 0.8 / 2
				data: 
					button: true
				onMouseDown: ()->
					scope.get('pane').visible = not scope.get('pane').visible
					scope.clipWindow()	
			# hideButton = new paper.Path.Circle
			# 	name: "hide"
			# 	fillColor: "#D8D8D8"
			# 	strokeColor: "#CACACA"
			# 	baseColor: new paper.Color "#FFBA2A"
			# 	strokeWidth: 2
			# 	radius: title.bounds.height * 0.8 / 2
			# 	data: 
			# 		button: true
			# 	
			button_group = new AlignmentGroup
				parent: title
				padding: 2
				orientation: "horizontal"
				anchor: 
					pivot: "leftCenter"
					position: t_bg.bounds.leftCenter
					offset: new paper.Point(3, 0)
				onMouseEnter: ()->
					buttons = this.getItems({data: {button: true}})
					_.each buttons, (b)->
						c = b.baseColor.clone()
						c.brightness += 0.1
						b.fillColor = c

			button_group.pushItem minimizeButton
			# button_group.pushItem hideButton
			@ui.title_bar = title
	makeScroll: ()->
		b = this.bounds.expand(0)
		b.height = this.max_height
		
		if @ui.scroll_bar then @ui.scroll_bar.remove()

		clip = @get("clipped")
		title_bar = @get("title_bar")

		scroll_bar = new Group
			parent: this
			name: "scroll_bar"
			
		scroll_bar_bg = new paper.Path.Rectangle
			parent: scroll_bar
			size: [10, clip.bounds.height - title_bar.bounds.height]
			fillColor: new paper.Color(0.95)
			strokeColor: "#CACACA"
			strokeWidth: 1
			
		scroll_bar.pivot = scroll_bar.bounds.bottomRight	
		scroll_bar.position = clip.bounds.bottomRight	
		

		pane = @get("pane")
		diff = pane.bounds.height - this.pane.max_height + 15
		island_height = scroll_bar.bounds.height * (1 - (diff/400))
		island_height = _.max([30, island_height])
		

		island = new paper.Path.Rectangle
			parent: scroll_bar
			name: "island"
			size: [scroll_bar.bounds.width * 0.8, island_height]
			fillColor: new paper.Color(0.5)
			shadowColor: new paper.Color(0.1)
			shadowBlur: 2

		island.pivot = island.bounds.topCenter	
		island.position = scroll_bar_bg.bounds.topCenter
		island.pivot = island.bounds.center

		@ui.scroll_bar = scroll_bar
		scope = this
		_.delay ()->
			island_path = new paper.Path.Line
				parent: scope
				from: scroll_bar_bg.bounds.topCenter.add(new paper.Point(0, island.bounds.height/2))
				to: scroll_bar_bg.bounds.bottomCenter.subtract(new paper.Point(0, island.bounds.height/2))
				data: 
					scroll: true
				strokeWidth: 1
				strokeColor: "black"
				visible: false
			island.set
				onMouseDown: (e)->
					this.fillColor.brightness = this.fillColor.brightness - 0.2
				onMouseDrag: (e)->
					this.position = island_path.getNearestPoint(e.point)
					param = island_path.getOffsetOf(this.position)/island_path.length
					scrollTop = param * diff - 55
					pane.pivot = pane.bounds.leftCenter
					pane.position = clip.bounds.leftCenter.add(new paper.Point(0, -scrollTop))
					e.stopPropagation()
				onMouseUp: (e)->
					this.fillColor.brightness = this.fillColor.brightness + 0.2



		renderLine = (data, plot)->
			lines = _.map data.data, (channel, k)->
				pts = _.map channel, (mag, i)->
					t = data.time[i]
					return [data.time[i], mag]
				plot.plotLine(pts, viz_settings.colors[k])
			plot.fitAxes()
		makePlot = (title, video)->
			plot = new TimePlot
				width: viz_settings.plot.width
				height: viz_settings.plot.height
				title: 
					content: title
				video: video
				orientation: "horizontal"
			plot.init()	
			return plot
		
		makeLegend = (labels)->
			console.log labels
		makeLegend(data.actors)
		# makeTracks()



class window.TimePlot extends paper.Group
	get: (name)->
		return this.getItem({name: name})
	init: ()->
		scope = this
		this.set 
			name: "plot"
		wrapper = new paper.Group
			parent: this
			name: "wrapper"	
		plot_wrapper = new paper.Group
			name: "plot_wrapper"
			parent: wrapper
			onMouseDrag: (e)->
				this.translate new paper.Point(e.delta.x, 0)
				e.stopPropagation(e)
		timeplot = new paper.Path.Rectangle
			name: "timeplot"
			parent: plot_wrapper
			size: [this.width * 2, this.height]
			fillColor: "white"
			strokeColor: new paper.Color(0.9)
			strokeWidth: 1
			onMouseDown: (e)->
				p = _.min([_.max([0, (e.point.x - this.parent.bounds.topLeft.x)/this.parent.bounds.width]), 1])
				video = $('video')[0]
				if $('video').attr('src') != scope.video
					$('video').attr('src', scope.video)
					video.addEventListener 'loadeddata', ()->
					  this.currentTime = this.duration * p
					  this.play()
				else	
				
					video.currentTime = video.duration * p
					video.play()
				
		timeline = new paper.Path.Line
			name: "timeline"
			parent: plot_wrapper
			from: timeplot.bounds.leftCenter
			to: timeplot.bounds.rightCenter
			strokeColor: "#00A8E1"
			start: 0
			end: 6 * 60
		clip = new paper.Path.Rectangle
			name: "clip"
			parent: wrapper
			size: [this.width, this.height]
			clipMask: true

		if this.title 
			@addTitle()
	addTitle: ()->
		ops = 
			name: "title"
			parent: this
			content: ""
			fillColor: 'black'
			fontFamily: 'Avenir'
			fontSize: 10	
			justification: 'center'
		ops = _.extend ops, this.title
		t = new paper.PointText ops
			
		t.rotate(90+180)
		t.position = this.get('clip').bounds.leftCenter.clone().add(new paper.Point(-t.bounds.width/2, 0))
	plotLine: (data, color)->
		plot_wrapper = this.get("plot_wrapper")
		timeline = this.get("timeline")
		
		pts = _.filter data, (pt)-> return pt[0] >= timeline.start and pt[0] <= timeline.end
		line = new paper.Path.Line
			parent: plot_wrapper
			strokeColor: color
			strokeWidth: 1
			segments: pts
			data: 
				line: true
				pts: data

	fitAxes: ()->		
		plot_wrapper = this.get("plot_wrapper")
		timeplot = this.get("timeplot")
		plot_height = timeplot.bounds.height
		plot_width = timeplot.bounds.width
		lines = this.getItems {data: {line: true}}

		lw_max = (_.max lines, (line)-> return line.bounds.width).bounds.width			
		lh_max = (_.max lines, (line)-> return line.bounds.height).bounds.height

		_.each lines, (line)-> line.scaling.x = (plot_width)/lw_max
		_.each lines, (line)-> line.scaling.y = (plot_height - 10)/lh_max
		
		_.each lines, (line)-> 
			line.pivot = line.bounds.leftCenter
			line.position = timeplot.bounds.leftCenter

	plotEvent: (event, videoURL)->
		plot_wrapper = this.get("plot_wrapper")
		timeline = this.get("timeline")
		
		event_orig = _.clone event
		if event.start > timeline.end then return
		if event.end < timeline.start then return
		if event.start < timeline.start then event.start = timeline.start
		if event.end > timeline.end then event.end = timeline.end
		
		pos = event.start - timeline.start
		pos_p = pos / (timeline.end - timeline.start)
		duration = event.end - event.start
		duration_p = duration / (timeline.end - timeline.start)
		max = (timeline.end - event.start) / (timeline.end - timeline.start)
		
		width = duration_p * timeline.length
		position = timeline.getPointAt(pos_p * timeline.length)
		
		e = new paper.Path.Rectangle
			parent: plot_wrapper
			name: "event"
			size: [width, this.height]
			fillColor: event.color
			data: event_orig
			onMouseDown: (e)->
				if $('video').attr('src') != videoURL then $('video').attr('src', videoURL)
				video = $('video')[0]
				video.currentTime = event_orig.start
				video.play()
				codes = _.flatten [event.actor, event.codes]
				$("#video-container .label").removeClass()
					.addClass(event.color).addClass('ui label ribbon')
					.html(codes.join('<span><i class="ui angle right icon"></i></span>'))
		e.pivot = e.bounds.leftCenter
		e.position = position	

# makeTracks = ()->
			# panel = new AlignmentGroup
			# 	name: "panel"
			# 	shading: true
			# 	moveable: true
			# 	anchor: 
			# 		pivot: "topCenter"
			# 		position: paper.project.getItem({name: "legend"}).bounds.bottomCenter.add(new paper.Point(0, 15))
			
			# # TRACK CREATION			
			# track_window = new AlignmentGroup
			# 	name: "data_pane"
			# 	shading: true
			# 	moveable: false
			# 	title: 
			# 		content: "DATAPANE"
			# 		buttons: true
			# 	pane: 
			# 		padding: 5
			# 		orientation: "vertical"
			# 		background:
			# 			fillColor: new paper.Color(0.7)
			# 			padding: [30, 15]
			# track_window.init()
			# track_window.pushItem new paper.Path.Circle
			# 	radius: 100
			# 	fillColor: "red"	
		
			# panel.pushItem track_window



			# _.each data.activity, (activity, user)->
			# 	track = new AlignmentGroup
			# 		name: "track"
			# 		padding: 10
			# 		orientation: "horizontal"

			# 	label = new LabelGroup
			# 		orientation: "horizontal"
			# 		text: user
			# 		onMouseDown: (e)->
			# 			$('video').attr('src', activity.video.mp4)
			# 	# label2 = new LabelGroup
			# 	# 	orientation: "horizontal"
			# 	# 	text: user + "2"
			# 	# 	onMouseDown: (e)->
			# 	# 		$('video').attr('src', activity.video.mp4)

			# 	plot_container = new AlignmentGroup
			# 		name: "plot_container"
			# 		padding: 5
			# 		orientation: "vertical"
			# 		backgroundColor: "#F0F0F0"

			# 	if viz_settings.render_codes
			# 		code_plot = makePlot('codes', activity.video.mp4)
			# 		_.each activity.video.codes, (event)-> code_plot.plotEvent(event, activity.video.mp4)
			# 		plot_container.pushItem(code_plot)
				
			# 	# if viz_settings.render_iron_imu
			# 	# 	_.each activity.iron.imu, (sensor_data, k)->
			# 	# 		p = makePlot(k, activity.video.mp4)
			# 	# 		renderLine(sensor_data, p)
			# 	# 		plot_container.pushItem p

			# 	track.pushItem label
			# 	# track.pushItem label2
			# 	track.pushItem plot_container
			# 	track_window.pushItem track


			.ui.container
  .ui.segment.session
    .node
      .label
        %span Molly
      .panel
        .node
          .label
            %span Iron
          .panel
            .node
              .label
                %span Acc
              .panel.paper
                Stuff
            .node
              .label
                %span Gyro
              .panel.paper
                Stuff
            .node
              .label
                %span Mag
              .panel.paper
                Stuff

    .node
      .label
        %span Cesar
      .panel
        .node
          .label
            %span Iron
          .panel
            .node
              .label
                %span Acc
              .panel.paper
                Stuff
            .node
              .label
                %span Gyro
              .panel.paper
                Stuff
            .node
              .label
                %span Mag
              .panel.paper
                Stuff
        .node
          .label
            %span Env
          .panel
            .node
              .label
                %span Audio
              .panel.paper
                Stuff
            .node
              .label
                %span Codes
              .panel.paper
                Stuff
			