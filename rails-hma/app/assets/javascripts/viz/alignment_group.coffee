# EXAMPLE_USAGE
# g = new AlignmentGroup
# 	name: "users"
# 	title: 
# 		content: "SESSIONS"
# 		orientation: "vertical"
# 	moveable: true
# 	padding: 5
# 	orientation: "vertical"
# 	background: 
# 		fillColor: "white"
# 		padding: 5
# 		radius: 5
# 		shadowBlur: 5
# 		shadowColor: new paper.Color(0.9)
# 	anchor: 
# 		pivot: "topLeft"
# 		object: paper.view
# 		magnet: "topLeft"
# 		offset: new paper.Point(5, 430)

class window.AlignmentGroup extends paper.Group
	init: ()->
		this.on 'mousedown', (e)-> this.bringToFront()
		return this
	pushItem: (obj)->
		wipe this, {data: {ui: true}}
		lc = this.lastChild		
		obj.parent = this
		obj.data.item = true

		if lc
			this.alignment = this.alignment or "center"
			switch this.orientation
				when "vertical"
					pinA = "top" + this.alignment.capitalize()
					pinB = "bottom" + this.alignment.capitalize()
					
					obj.pivot = obj.bounds[pinA]
					obj.position = lc.bounds[pinB].add(new paper.Point(0, this.padding))
					obj.pivot = obj.bounds.center
				when "horizontal"
					obj.pivot = obj.bounds.leftCenter
					obj.position = lc.bounds.rightCenter.add(new paper.Point(this.padding, 0))
					obj.pivot = obj.bounds.center
	
		@ui_elements()
		@reposition()

	ui_elements: ()->
		if this.background
			if this.children.background then this.children.background.remove()
			if this.background.padding
				if not this.background.padding.x
					this.background.padding = 
						x: this.background.padding
						y: this.background.padding

			bg = new paper.Path.Rectangle
				parent: this
				name: "background"
				rectangle: this.bounds.expand(this.background.padding.x + 10, this.background.padding.y)
				radius: 0 or this.background.radius 
			bg.set this.background
			bg.sendToBack()
		if this.moveable and this.children.length != 0
			handle = new paper.Path.Rectangle
				parent: this
				name: "handle"
				size: [15, this.bounds.height]
				fillColor: new paper.Color("#F5F5F5")
				strokeColor: new paper.Color("#CACACA")
				strokeWidth: 1
				data: 
					ui: true
				onMouseDrag: (e)->
					previous = this.parent.position.clone()
					this.parent.translate e.delta
					if not paper.view.bounds.contains(this.parent.bounds)
						this.parent.position = previous
					e.stopPropagation()	

			handle.pivot = handle.bounds.rightCenter.subtract(new paper.Point(5, 0))
			handle.position = this.children.background.bounds.leftCenter
		if this.title
			ops = 
				name: "title"
				parent: this
				content: ""
				fillColor: 'black'
				fontFamily: 'Adobe Gothic Std'
				fontSize: 12
				fontWeight: "bold"
				justification: 'center'
				data:
					ui: true
			
			ops = _.extend ops, this.title

			t = new paper.PointText ops
			
			if not this.title.orientation
				t.pivot = t.bounds.bottomLeft
				t.position = this.children.background.bounds.topLeft.add(new paper.Point(10,-3))
			else
				t.rotation = -90
				t.position = this.children.background.bounds.leftCenter.add(new paper.Point(0,0))	
				t.pivot = t.bounds.rightCenter
				t.position = this.children.background.bounds.leftCenter.add(new paper.Point(t.bounds.width * 1.8,0))
			
	setTitle: (spec)->
		this.children.title.content = spec
	clear: ()->
		wipe this, {data: {item: true}}
		wipe this, {data: {ui: true}}
		@ui_elements()
		@reposition()
	reposition: ()->
		if this.anchor
			if this.anchor.pivot 
				this.pivot = this.bounds[this.anchor.pivot]
			if not this.anchor.offset
				this.anchor.offset = new paper.Point(0, 0)
			if this.anchor.position
				this.position = this.anchor.position.add(this.anchor.offset)
			else if this.anchor.object
				this.position = this.anchor.object.bounds[this.anchor.magnet].add(this.anchor.offset)
