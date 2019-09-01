				
class window.LabelGroup extends AlignmentGroup
	constructor: (op)->
		super op
		if op.key then this.pushItem op.key
		if op.text
			op.text = if _.isString op.text then {content: op.text} else op.text
			ops = 
				name: "label"
				fillColor: 'black'
				fontFamily: 'Avenir'
				fontWeight: 'bold'
				fontSize: 12	
			ops = _.extend ops, op.text
			t = new paper.PointText ops
			this.pushItem t
		if not this.hoverable
			if not this.children.hover
				hover = new paper.Path.Rectangle
					parent: this
					name: "hover"
					rectangle: this.bounds.expand(10, 5)
					radius: 5
				hover.sendToBack()
			this.on('mouseenter', (e)-> this.children.hover.fillColor = new paper.Color(0.9, 0.3))
			this.on('mousemove', (e)-> this.children.hover.fillColor = new paper.Color(0.9, 0.3))
			this.on('mousedown', (e)-> this.children.hover.fillColor = new paper.Color(0.8, 0.6))
			this.on('mouseup', (e)-> this.children.hover.fillColor = new paper.Color(0.9, 0.3))
			this.on('mouseleave', (e)-> this.children.hover.fillColor = new paper.Color(0.9, 0))
			this.hoverable = true
			if this.button
				background = new paper.Path.Rectangle
					parent: this
					name: "background"
					rectangle: hover.bounds
					radius: 5
					fillColor: "white"
					strokeColor: "#CACACA"
					strokeWidth: 1
				hover.sendToBack()
				background.sendToBack()
				background.set this.button
			
	updateLabel: (lab)->
		this.children.label.content = lab