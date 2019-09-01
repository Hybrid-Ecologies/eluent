window.activeUser = null
window.user_list = null
window.avatars =
	Male:[
		"m1.png"
		"m2.png"
		"m3.jpeg"
		"m4.png"
		"m5.jpeg"
		"m6.png"
		"m7.jpeg"
		"m8.jpeg"
		"m9.jpeg"
	]
	Female:[
		"w1.png"
		"w2.jpeg"
		"w3.png"
		"w4.jpeg"
		"w5.jpeg"
		"w6.jpeg"
		"w7.png"
		"w8.jpeg"
		"w9.jpeg"
		"w9.png"
	]


class window.ProfileManager
	constructor: (op)->
		scope = this

		$('#user-select').dropdown
			onChange: (value, text, $choice)->
				user = parseInt($choice.attr('id'))
				scope.load_user(user)

		$('.ui.rating').rating
			maxRating: 7

		$.getJSON "/users.json", (data)->
			window.user_list = data

			_.each data, (info, user)->
				id = _.keys(user_list).indexOf(user.toString())

				# POPULATE USER LIST
				p = $("#user-select").find(".item.template").attr('id', user)
					.clone().removeClass("template").removeClass("hidden")
					.appendTo($("#user-select .menu"))
				img = avatars[info.Gender][id%avatars[info.Gender].length]
				age = info.Age
				p.find(".user").html(user)
				p.find('img').attr('src', "/avatars/" + img)

				# ADDITIONAL DESCRIPTOR
				_.each info, (val, prop)->
					prop = prop.toLowerCase().replaceAll(" ", "_")
					if prop == "years_programming"
						val = /\d+/.exec(val)[0]
					span = p.find("." +prop)
					if span.hasClass('rating')
						span.data('rating', val)
					else
						span.html(val)

			op.onLoad()

	load_user: (user)->
		_.each $(".paper-plot"), (p)->
			src = $(p).attr('src')
			if src
				src = src.replaceAll(activeUser, user)
				$(p).attr('src', src)
				console.log "loading", src
		src = $("#metadata").attr('src')
		src = src.replaceAll(activeUser, user)
		$("#metadata").attr('src', src)

		$(".paper-plot").trigger('load')

		window.activeUser = user
		# $('track').attr('src', $(this).val().replaceAll('111', activeUser))
		$('#codebook-select').trigger('change')
		$('.plottitle.chromatogram').html("User " + user)
		# parents(".segment").find('.paper-plot').trigger('load')

		@load_profile(user)




		configureResource
			user: user
			metadata: "notesmetadata"
			default: "transcript"
			select: $('#notes-display select')

		configureResource
			user: user
			metadata: "videometadata"
			default: "screen"
			select: $('#primary-display select')

		configureResource
			user: user
			metadata: "videometadata"
			default: "side"
			select: $('#secondary-display select')


	load_profile: (user)->
		console.log "LOADING PROFILE", user
		scope = this
		info = user_list[user]

		id = _.keys(user_list).indexOf(user.toString())
		$('#avatar').attr('src', "/avatars/"+avatars[info.Gender][id])
		profile = $('#user-profile .content')

		_.each info, (value, prop)->

			prop = prop.toLowerCase().replaceAll(" ", "_")
			span = profile.find("." +prop)
			if prop == "years_programming"
				value = /\d+/.exec(value)[0]
			if prop == "programming_background_and_style"


				value = scope.programming_background_and_style(value)


			if _.isObject(value)
				if not _.isArray(value)
					value_p = _.map value.Positive, (v)-> return $('<span>').html(v)
					value_n = _.map value.Negative, (v)-> return $('<span>').html(v)
					not_span = $('<span></span>').addClass('not').html("not")
					value = value_p

				if span.hasClass('list')
					span.find('.item').not('.template').remove()
					_.each value, (v)->
						$(span).find('.template').clone()
							.removeClass("template").removeClass("hidden")
							.appendTo(span)
							.find('.value').html(v)
				else
					span.find("."+prop).html(value)
			else


				if span.hasClass('rating')
					span.rating("set rating", parseInt(value))
				else
					span.html(value)
	semantify_list: (prefix, arr, suffix)->
		if arr.length == 0
			return ""
		else if arr.length == 1
			a = arr[0]
			return "#{prefix}#{a}#{suffix}"
		else
			a = arr.slice(0, -1).join(', ')
			b = arr.slice(-1)
			return "#{prefix}#{a} and #{b}#{suffix}"

	programming_background_and_style: (value)->
		scope = this
		semantics =
			exposure: []
			learn: []
			other: []
		keys = _.keys semantics

		_.each keys, (k)->
			semantics[k] = _.filter value, (v)->
				return v.toLowerCase().includes(k)

		semantics["other"] = _.difference(value, _.flatten(_.values(semantics)))
		learning = _.map semantics.learn, (l)->
			l = l.split(" ")[0].toLowerCase()
			if _.contains(["collaborative", "independent"], l)
				l = l + "ly"
			return l
		learning_s = scope.semantify_list("User #{activeUser} learns best from ", learning, ".")

		exposure = _.map semantics.exposure, (l)-> l.split(" ")[0].toLowerCase()
		exposure_s = scope.semantify_list("They had ", exposure, " exposure to programming.")
		other_s = scope.semantify_list("They consider themselves a ", semantics.other, ".")

		return "#{learning_s} #{exposure_s} #{other_s}"
