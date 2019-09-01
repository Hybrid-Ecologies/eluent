$ ->
	force()

window.force = ()->
	$(".toggle-menu").click ()->
		$(this).parents('.segment').find(".change").toggleClass("hidden")
		$(this).toggleClass('blue')
	$(".toggle-menu").click()
	
window.configureResource = (op)->
	loadFile op.user, op.metadata, (data)->
		data = _.values(data)
		data = _.flatten(data)
		if not _.isString data[0]
			data = _.pluck(data, "opt")
		
		op.select.children("option").remove()
		_.each data, (f)->
			name = f.split("/").slice(-1)[0]
			name = name.split(".")[0]
			f = "/" + f # REMOVE FOR PYTHON
			opt = $('<option></option>').attr('value', f).html(name).appendTo(op.select)
			if name.startsWith(op.default+"_"+op.user)
				op.select.val(opt.attr('value'))
			
		op.select.trigger("change")

window.loadFile = (user, feature, callback)->
	path = ["", "irb", user, feature+"_"+user+".json"]
	$.getJSON path.join("/"), (data)->
		callback(data)
	

class window.UIManager
	constructor: ()->
		vm = new VideoManager()

class window.VideoManager
	constructor: ()->
		@zoomify()
	handlers: ()->
		scope = this
		

		$('button.remove').click ()->
			$(this).parents('.segment').hide()

		$('.panel > .segment').resizable(
			aspectRatio: 16/9
			minWidth: 210
			containment: "parent"
			helper: "ui-resizable-helper"
			stop: (event, ui)->
				$(ui.element).find('video').trigger("loadstart")
		).draggable(
			containment: "parent"
			stack: ".segment"
		)

		$(".toggle-menu").click ()->
			$(this).parents('.segment').find(".change").toggleClass("hidden")
			$(this).toggleClass('blue')
		# $(".toggle-menu").click()
		

		
		$('.aspect').click ()->
			aspect = parseFloat($(this).attr('name'))
			$(this).attr('name', 1/aspect).toggleClass('active')
			$(this).parents(".segment").resizable("option", "aspectRatio", 1/aspect)
			if $(this).hasClass('active')
				$(this).html('3:4')
			else
				$(this).html('4:3')
			
	

	zoomify: ()->
		@handlers()
		STEP = 30

		### Array of possible browser specific settings for transformation ###
		stage = $('.stage')[0]
		properties = [
			'transform'
			'WebkitTransform'
			'MozTransform'
			'msTransform'
			'OTransform'
		]
		prop = properties[0]

		### Iterators and stuff ###

		i = undefined
		j = undefined
		t = undefined

		### Find out which CSS transform the browser supports ###

		i = 0
		j = properties.length
		while i < j
			if not _.isUndefined stage.style[properties[i]]
				prop = properties[i]
				break
			i++


		displays = $(".video-display")

		### predefine zoom and rotate ###
		_.each displays, (d)->
			d = $(d)
			d.data('zoom', 1)
			d.data('rotate', 0)
			

		_.each displays, (d)->
			d = $(d)
			zoom = parseFloat(d.data('zoom'))
			rotate = parseFloat(d.data('rotate'))
			### Grab the necessary DOM elements ###
			s = d.find('.stage')
			v = d.find('video')[0]
			controls = d.find('#controls')
			# console.log("CONTROL", controls.children('button')
			### Position video ###

			v.style.left = 0
			v.style.top = 0

			$(controls).find('button.tplay').on 'play', ()->
				if not v.paused
					$(this).find('i').removeClass('play').addClass('pause')
				else
					$(this).find('i').addClass('play').removeClass('pause')		
				
			$(controls).find('button').click (e) ->
				e.preventDefault()
				t = $(this)
				className = t.attr('class').split(' ').slice(-2)[0].slice(1)
				switch className
					when 'play'
						
						if v.playing
							v.pause()
						else
							v.play()
						t.trigger('play')
					when 'zoomin'
						zoom = zoom + 0.1
						v.style[prop] = 'scale(' + zoom + ') rotate(' + rotate + 'deg)'
					when 'zoomout'
						zoom = zoom - 0.1
						v.style[prop] = 'scale('+zoom+') rotate('+rotate+'deg)'
					when 'rotateleft'
						rotate = rotate + 5
						v.style[prop] = 'rotate(' + rotate + 'deg) scale(' + zoom + ')'
					when 'rotateright'
						rotate = rotate - 5
						v.style[prop] = 'rotate(' + rotate + 'deg) scale(' + zoom + ')'
					when 'left'
						v.style.left = parseInt(v.style.left, 10) - STEP + 'px'
					when 'right'
						v.style.left = parseInt(v.style.left, 10) + STEP + 'px'
					when 'up'
						v.style.top = parseInt(v.style.top, 10) - STEP + 'px'
					when 'down'
						v.style.top = parseInt(v.style.top, 10) + STEP + 'px'
					when 'reset'
						zoom = 1
						rotate = 0
						v.style.top = 0 + 'px'
						v.style.left = 0 + 'px'
						v.style[prop] = 'rotate(' + rotate + 'deg) scale(' + zoom + ')'
				d.data('zoom', zoom)
				d.data('rotate', rotate)
