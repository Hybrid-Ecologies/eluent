# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
#= require moment
#= require paper
#= require jquery-ui/core
#= require jquery-ui/widget
#= require jquery-ui/position
#= require jquery-ui/widgets/mouse
#= require jquery-ui/widgets/draggable
#= require jquery-ui/widgets/resizable
#= require ui_manager
#= require plot_manager
#= require profile

		
Object.defineProperty HTMLMediaElement.prototype, 'playing', get: ->
  ! !(@currentTime > 0 and !@paused and !@ended and @readyState > 2)

window.cues = null

window.handlers = (callback)->
	SPACE_BAR = " "
	$("body").keypress (e)->
		if e.key == SPACE_BAR #
			_.each $('video'), (v)-> 
				if v.playing then v.pause() else v.play()
			e.preventDefault()

	$('.plottitle').click ()->
		$(this).toggleClass('timeupdate')
	

	$('video').on 'timeupdate', (e)->
		if _.isNaN(this.duration) then return
		event = jQuery.Event("scrubupdate")
		event.p = this.currentTime / this.duration
		$('.timeupdate').siblings(".paper-plot").trigger(event)
		# $(".paper-plot").trigger(event)

	$("video").on "loadstart", ()->
		video = $(this)
		force()
		stage = $(this).parent()
		segment = $(this).parents(".segment")
		aspectRatio = parseFloat(segment.find('.aspect').attr('name'))
		video.height(video.width()/aspectRatio)
		h = video.height()
		w = video.width()
		stage.height(h)
		segment.height((w+30)/aspectRatio)
	.on 'play', ()->
		$('.tplay').trigger('play')
	.on 'pause', ()->
		$('.tplay').trigger('play')
		
	$('track').on "load", (e)->
		track = this.track
		track.mode = 'hidden'
		window.cues = _.map track.cues, (cue)->
			if !cue.data
				cue.data = JSON.parse(cue.text)
				cue.text = cue.data.code
			return cue.data
		callback()
		window.code_legend = _.map cues, (c)-> return {code: parseInt(c.code), color: c.color}
		window.code_legend = _.sortBy(_.unique(code_legend, (c)-> c.code), (e)-> e.code)
		
		# ADDING CODE TOGGLE BUTTONS
		$(".codes").html("")
		_.each code_legend, (cl)->
			$('<button>').addClass(".ui.button").css('background', cl.color).html(cl.code).appendTo($(".codes")).click (e)->
				console.log "TOGGLE", cl.code, plt.plots
				if plt.plots.chromatogram
					_.each plt.plots.chromatogram.getItems({code: cl.code}), (cw)-> cw.visible = !cw.visible
	.on "error", ()->
		window.cues = []
		console.log "No cues found."
		$('.paper-plot.chromatimeline').trigger("load")			
	vid = $('video')[0]
	$('track').on "cuechange", (c) ->
		if vid.textTracks[0].activeCues.length > 0
			cue = vid.textTracks[0].activeCues[0].data		
			# console.log("Track", cue)
			if cue
				if cue.color
					$('.codeword').css 'background', cue.color
				else
					$('.codeword').css 'background', "black"
				$('.codelabel').html "C" + cue.code + "<br>"+ cue.width


	$('#codebook-select').on 'change', (e)->
		$('track').attr('src', $(this).val().replaceAll('111', activeUser))
		console.log "Loading", activeUser
		$(this).parents(".segment").find('.paper-plot').trigger('load')
		cb = $(this).val().split("/")[3].split("_")[0]
		
		$('.cgram img').attr "src", "/irb/datasets/images/"+cb+"_cbook.png"
			.parent().unbind().click ()->
				$(this).toggleClass("full")
		$('.cbook img').attr "src", "/irb/datasets/images/"+cb+"_cgram.png"
			.parent().unbind().click ()->
					$(this).toggleClass("full")
		$('.cchar img').attr "src", "/irb/datasets/images/"+cb+"_char.png"
			.parent().unbind().click ()->
					$(this).toggleClass("full")
		
		console.log "CODEBOOK SELECT", cb

	$(".video-display select").on 'change', (e)->
			container = $(this).parents(".segment")
			container.find("video").attr('src', this.value)
			aspect = container.find(".aspect").attr('name')

	$("#notes-display select").on 'change', (e)->
		$.get this.value, (data)->
			lines = data.split('\n')
			markdown = _.map lines, (l)->
				l = l.trim()
				prefix = l.slice(0, 3)
				if l.slice(0, 3) == "###"
					l = "<h3>"+l.slice(4)+"</h3>"
				else if l.slice(0, 2) == "##"
					l = "<h2>"+l.slice(3)+"</h2>"
				else if l.slice(0, 1) == "#"
					l = "<h1>"+l.slice(1)+"</h1>"
				else
					l = "<p>"+l+"</p>"
				
				return l
			$("#notes").html(markdown.join('\n'))







	