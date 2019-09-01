window.makeTriangle = (op)->
	x = op.pos * op.track.length
	a = op.track.getPointAt(x)
	base = op.track.getPointAt(x - op.height)
	b = op.track.getNormalAt(x - op.height).multiply(op.width).add(base)
	c = op.track.getNormalAt(x - op.height).multiply(-1 * op.width).add(base)
	tri = new paper.Path
		fillColor: "red"
		segments: [a, b, c]
		closed: true
	tri.set op.style

$ ->
	if not GET().file
		return
	statfile = "/irb/datasets/" + GET().file+ ".json"

	$.getJSON statfile, (data)->
		# PROCESS DATA
		features = data.features
		data = data.data
		final = _.map data, (segments, code)->
			return _.map segments, (s)->
				return _.map s.data, (feature_data, fid)->
					feature = features[fid]
					node =
						from: s.from
						to: s.to
						code: code
						feature: feature
						average: arr.average feature_data
						stddev: arr.standardDeviation feature_data
					return node

		data =_.flatten(final)
		visualizeData(data)

	visualizeData = (data)->
		tt = makeTimeline(false)
		_.each data, (d)->
			plot(tt, d)
		# tt.bringToFront()

	plot = (tt, d) ->
		gs = new PracticeNode
		
		gs.init
			data: d
			time_track: tt

window.kinnunen_colors = 
	"getting-started": "purple"
	"dealing-with-difficulties": "orange"
	"encountering-difficulties": "red"
	"failing": "blue"
	"succeeding": "green"
	"submitting": "teal"

class PracticeNode extends paper.Group
	init: (op)->
		
		tt = op.time_track
		r = (op.data.to - op.data.from) * tt.length
		p = (op.data.to - op.data.from) / 2 + op.data.from
		pos = tt.length * p

		c = new paper.Path.Rectangle
			size: [op.data.average * 1000, r]
			# size: [0.5 * 1000, r]
			# radius: op.data.average * 1000
			fillColor: kinnunen_colors[op.data.code]
			position: tt.getPointAt(pos)	
			opacity: 0.5
		# c.rotation = tt.getTangentAt(pos).angle	
		
		console.log  op.data.to - op.data.from
		# _.each @data, (x)->
			# p = (x.to - x.from)/2 + x.from

			# makeTriangle
			# 	pos: x.to
			# 	width: x.features.acc.mean
			# 	height: (x.to - x.from) * tt.length
			# 	track: tt
			# 	style: 
			# 		fillColor: "orange"
			# 		strokeWidth: 2
			# 		strokeColor: "black"


			# makeTriangle
			# 	pos: x.to
			# 	width: x.features.acc.mean +  x.features.acc.stdev
			# 	height: (x.to - x.from) * tt.length
			# 	track: tt
			# 	style: 
			# 		fillColor: "orange"
			# 		strokeWidth: 2
			# 		opacity: 0.5

			# pos = tt.length * p 
			# r = (x.to - x.from)/2
			# console.log r, pos





makeTimeline = (circular)->
	paper = Utility.paperSetup($('canvas'))
	
	if circular
		c = new paper.Path.Circle
			radius: 200
			strokeColor: "red"
			strokeWidth: 4
			position: paper.view.center
		c.rotate(-90)
	else
		c = new paper.Path.Line
			from: paper.view.bounds.leftCenter.add(new paper.Point(100, 0))
			to: paper.view.bounds.rightCenter.subtract(new paper.Point(100, 0))
			strokeColor: "red"
			strokeWidth: 4
			position: paper.view.center

	resample = _.range(10, c.length - 10, 1)
	segs = _.map resample, (l)->
		return c.getPointAt(l)
	c.remove()
	tt = new paper.Path
		strokeColor: "black"
		strokeWidth: 4
		segments: segs
		position: paper.view.center
	

	makeTriangle
		pos: 1
		width: 15
		height: 20
		track: tt
		style:
			fillColor: "black"

	n = tt.length
	while tt.length > n - 18
		tt.lastSegment.remove()
	return tt


