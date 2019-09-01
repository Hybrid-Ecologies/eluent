# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
# vendor/assets/javascripts directory can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# compiled file. JavaScript code in this file should be added after the last require_* statement.
#
# Read Sprockets README (https:#github.com/rails/sprockets#sprockets-directives) for details
# about supported directives.
#
#= require rails-ujs
#= require jquery
#= require jquery_ujs
#= require angular
#= require semantic-ui
#= require webstorage
#= require alertify
#= require underscore
#= require saveas.min

$ ->
  $('.ui.dropdown').dropdown()
  alertify.set('notifier','position', 'bottom-left');

 
$(()->
  _.mixin isColorString: (str)->
    return typeof str == 'string' && str[0] == "#" && str.length == 7
  _.mixin zeros: (length)->
    return Array.apply(null, Array(length)).map(Number.prototype.valueOf,0)
  _.mixin fill: (length, v)->
    return Array.apply(null, Array(length)).map(Number.prototype.valueOf,v)
  _.mixin repeat: (func, interval)->
    args = _.last arguments, 2
    return setInterval(_.bind(func, null, args), interval);
  _.mixin sum: (arr)->
    return _.reduce arr, ((memo, num)-> return memo + num ), 0
    
  String.prototype.replaceAll = (search, replacement)->
    target = this
    return target.replace(new RegExp(search, 'g'), replacement)
  
)

window.rgb2hex = (rgb) ->
  rgb = rgb.match(/^rgba?[\s+]?\([\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?/i)
  if rgb and rgb.length == 4 then '#' + ('0' + parseInt(rgb[1], 10).toString(16)).slice(-2) + ('0' + parseInt(rgb[2], 10).toString(16)).slice(-2) + ('0' + parseInt(rgb[3], 10).toString(16)).slice(-2) else ''

window.rgb2hex2 = (rgb) ->
  rgb = rgb.match(/^rgba?[\s+]?\([\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?/i)
  if rgb and rgb.length == 4 then '0x' + ('0' + parseInt(rgb[1], 10).toString(16)).slice(-2) + ('0' + parseInt(rgb[2], 10).toString(16)).slice(-2) + ('0' + parseInt(rgb[3], 10).toString(16)).slice(-2) else ''
transformToAssocArray = (prmstr) ->
  params = {}
  prmarr = prmstr.split('&')
  i = 0
  while i < prmarr.length
    tmparr = prmarr[i].split('=')
    params[tmparr[0]] = tmparr[1]
    i++
  params
window.GET = ->
  prmstr = window.location.search.substr(1)
  if prmstr != null and prmstr != '' then transformToAssocArray(prmstr) else {}

window.guid = ->
  s4 = ->
    Math.floor((1 + Math.random()) * 0x10000).toString(16).substring 1
  s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4()

window.poly = (a, b, c, x) ->
  x ** 2 * a + x * b + c

window.capitalize = (string)->
  return string.charAt(0).toUpperCase() + string.slice(1)

Math.radians = (degrees) ->
  degrees * Math.PI / 180

Math.degrees = (radians) ->
  radians * 180 / Math.PI

if !Date.now
  Date.now = ->
    (new Date).getTime()

window.DOM = ->

window.DOM.tag = (tag, single) ->
  if single
    $ '<' + tag + '/>'
  else if typeof single == 'undefined'
    $ '<' + tag + '>' + '</' + tag + '>'
  else
    $ '<' + tag + '>' + '</' + tag + '>'

Object.size = (obj) ->
  size = 0
  key = undefined
  for key of obj
    if obj.hasOwnProperty(key)
      size++
  size
window.objectToFormData = (obj, form, namespace) ->
  fd = form or new FormData
  formKey = undefined
  for property of obj
    if obj.hasOwnProperty(property)
      if namespace
        formKey = namespace + '[' + property + ']'
      else
        formKey = property
      # if the property is an object, but not a File,
      # use recursivity.
      if typeof obj[property] == 'object' and !(obj[property] instanceof File)
        objectToFormData obj[property], fd, property
      else
        # if it's a string or a File object
        fd.append formKey, obj[property]
  fd


window.Utility = ->

window.Utility.paperSetup = (id, op) ->
  dom = if typeof id == 'string' then $('#' + id) else id
  # w = dom.parent().height()
  if op and op.width then dom.parent().width(op.width+1)
  if op and op.width then dom.width(op.width+1)
  if op and op.height then dom.parent().height(op.height+1)
  if op and op.height then dom.height(op.height)
  # dom.attr 'height', w
  # dom.attr 'width', '90px'
  paper.install window
  myPaper = new (paper.PaperScope)
  myPaper.setup dom[0]
  # if typeof id == 'string'
  #   console.info 'Paper.js installed on', id, w, 'x', h
  # else
  #   console.info 'Paper.js installed:', w, 'x', h
  myPaper

window.installPaper = (dimensions)->
  # PAPER SETUP
  markup = $('canvas#markup')[0]
  paper.install window
  vizpaper = new paper.PaperScope()
  vizpaper.setup(markup)
  vizpaper.settings.handleSize = 10
  loadCustomLibraries()
  return vizpaper

window.makePlot = (op)->
  c = $('<canvas></canvas>')
  op.parent.html(c)

  c.attr
    height: op.height
    width: op.parent.width()

  p = new paper.PaperScope()
  p.setup(c[0])
  p.settings.handleSize = 10
  p.plot = 
  	height: op.height
  return p



