class window.VizEnvironment
	constructor: (op)->
		_.extend this, op
		this.viz_settings = 
			padding: 30
			plot:
				height: 30
				width: 500
			colors: 
				0: "red"
				1: "green"
				2: "blue"
			render_iron_imu: false
			render_codes: true
	reposition_video: ()->
		if legend = paper.project.getItem({name: "legend"})
			pt = legend.bounds.bottomLeft
			$('#video-container').css
				top: pt.y + 30
				left: pt.x + 20
		
	renderData: (data)->
		window.installPaper()
		@makeLegend(data)
		
		this.timeline = new Timeline
			anchor: 
				pivot: "center"
				object: paper.view
				magnet: "center"
				offset: new paper.Point(0, 300)
			controls: 
				rate: true
		Timeline.load data.activity.cesar.env.video
		this.codeline = new CodeTimeline
			title: "CODES"
			anchor: 
				pivot: "bottomCenter"
				object: this.timeline.ui
				magnet: "topCenter"
				offset: new paper.Point(0, -25)
			controls: 
				rate: false

		this.sensorline = new SensorTimeline
			title: "SENSOR"
			anchor: 
				pivot: "bottomCenter"
				object: this.codeline.ui
				magnet: "topCenter"
				offset: new paper.Point(0, -50)
			controls: 
				rate: false

		@makeTracks(data)
		@ready()

	
	makeTracks: (data)->
		scope = this
		# LEGEND CREATION
		g = new AlignmentGroup
			name: "users"
			title: 
				content: "SESSIONS"
			moveable: true
			padding: 5
			orientation: "vertical"
			background: 
				fillColor: "white"
				padding: 5
				radius: 5
				shadowBlur: 5
				shadowColor: new paper.Color(0.9)
			anchor: 
				pivot: "topLeft"
				object: paper.view
				magnet: "topLeft"
				offset: new paper.Point(5, 430)
		g.init()

		actors_panel = new AlignmentGroup
			name: "actors_panel"
			title: 
				content: "ACTORS"
			moveable: true
			padding: 5
			orientation: "vertical"
			alignment: "left"
			background: 
				fillColor: "white"
				padding: 5
				radius: 5
				shadowBlur: 5
				shadowColor: new paper.Color(0.9)
			anchor: 
				pivot: "topCenter"
				object: g
				magnet: "bottomCenter"
				offset: new paper.Point(0, 5)
		@actors_panel = actors_panel.init()

		@activity = data.activity
		_.each data.activity, (data, user)->
			
			label = new LabelGroup
				orientation: "horizontal"
				padding: 5
				text: user
				data: 
					user: user
				onMouseDown: (e)->
					scope.activeUser = this.data.user
					scope.update()

			g.pushItem label

	update: ()->
		if _.isNull(this.activeUser) then return
		actors = @activity[this.activeUser]
		Timeline.load actors.env.video
		@updateActorPanel(actors)


	updateActorPanel: (actors)->
		scope = this
		panel = @actors_panel
		panel.clear()
		_.each actors, (sensors, actor)->
			l = new LabelGroup
				orientation: "horizontal"
				padding: 5
				text: actor
			panel.pushItem(l)
			_.each sensors, (channels, sensor)->
				s = new LabelGroup
					orientation: "horizontal"
					padding: 2
					text: 
						content: "  " + sensor
						fontWeight: "normal"
				panel.pushItem s
				_.each channels, (data, channel)->
					c = new LabelGroup
						orientation: "horizontal"
						padding: 1
						text: 
							content: " \t\t" + channel.toUpperCase()
							fontWeight: "normal"
							fontSize: 8
							onMouseDown: (e)->
								switch data.type
									when "codes_chart"
										if scope.codeline
											console.log scope.codeline, data
											scope.codeline.load channel, data
									when "sensor_plot"
										if scope.sensorline
											scope.sensorline.load channel, data

					panel.pushItem c


	makeLegend: (data)->		
		# LEGEND CREATION
		g = new AlignmentGroup
			name: "legend"
			title: 
				content: "ACTORS"
			moveable: true
			padding: 5
			orientation: "horizontal"
			background: 
				fillColor: "white"
				padding: 5
				radius: 5
				shadowBlur: 5
				shadowColor: new paper.Color(0.9)
			anchor: 
				position: paper.view.bounds.topCenter.add(new paper.Point(0, this.viz_settings.padding))
		g.init()

		_.each data.actors, (color, actor)->
			color_code = new paper.Color color
			color_code.saturation = 0.8
		
			label = new LabelGroup
				orientation: "horizontal"
				padding: 5
				key: new paper.Path.Circle
					name: actor
					radius: 10
					fillColor: color_code
					data: 
						actor: true
						color: color
				text: actor
				data:
					activate: true
				update: ()->
					codes = paper.project.getItems
						name: "tag"
						data: 
							actor: actor
					if this.data.activate 
						this.opacity = 1 
						_.each codes, (c)-> c.visible = true
					else 
						this.opacity = 0.2
						_.each codes, (c)-> c.visible = false
				onMouseDown: ()->
					this.data.activate = not this.data.activate
					this.update()
			g.pushItem label