#= require viz/data_grabber
#= require viz/environment
#= require viz/alignment_group
#= require viz/label_group
#= require viz/timeline

# $ ->
	# window.env = new VizEnvironment
	# 	ready: ()->
	# 		scope = this
	# 		@event_binding()
	# 		@keybinding()
	# 	event_binding: ()->
	# 		scope = this
	# 		$('.panel').draggable()
	# 		@reposition_video()
	# 		$(window).resize ()-> scope.reposition_video()
	# 		$("canvas").on 'wheel', (e)->
	# 			delta = e.originalEvent.deltaY
	# 			pt = paper.view.viewToProject(new paper.Point(e.originalEvent.offsetX, e.originalEvent.offsetY))
	# 			e = _.extend e, 
	# 				point: pt
	# 				delta: new paper.Point(e.originalEvent.deltaX, e.originalEvent.deltaY)
	# 			hits = _.filter paper.project.getItems({data: {class: "Timeline"}}), (el)->
	# 				return el.contains(pt)
	# 			_.each hits, (el)-> el.emit "mousedrag", e

	# 		$('video').on 'loadeddata', (e)->
	# 			_.each Timeline.lines, (line)->
	# 				line.ui.video = this
	# 				line.ui.range.timestamp = Timeline.ts
	# 				line.refresh()
	# 	keybinding: ()->				
	# 		paper.tool = new paper.Tool
	# 			video: $('video')[0]
	# 			onKeyDown: (e)->
	# 				switch e.key
	# 					when "space"
	# 						if this.video.paused then this.video.play() else this.video.pause()
	
	# grabber = new DataGrabber
	# 	success: (data)-> 
	# 		console.log data
	# 		env.renderData(data)

window.manifest = null
window.color_scheme = ["red","orange","blue","green","yellow","violet","purple","teal", "pink","brown","grey","black"]
window.data_source = "/data/compiled.json"

window.exportSVG = ()->
	exp = paper.project.exportSVG
    asString: true
    precision: 5
  saveAs(new Blob([exp], {type:"application/svg+xml"}), participant_id+"_heater" + ".svg");

window.wipe = (caller, match)->
  _.each caller.getItems(match), (el)-> el.remove()

String.prototype.capitalize = ()->
  return this.charAt(0).toUpperCase() + this.slice(1)
