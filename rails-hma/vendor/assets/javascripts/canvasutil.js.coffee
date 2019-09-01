# Allows for querying scene graph elements using prefix annotation
#    LEDS --> obj.query({prefix:['NLED']});
#    Interactive LEDS --> obj.query({prefix:['ILED']});
#    Breakout --> obj.query({prefix:['BO']});
#    Breakin --> obj.query({prefix:['BI']});
#    Breakin --> obj.queryPrefix("BI");

window.CanvasUtil = ->
# queryable: ->
#   _.map @query({}), (el) ->
#     el.name   
CanvasUtil.import = (filename, options) ->
  extension = filename.split('.')
  extension = extension[extension.length - 1]
  if extension == 'svg'
    paper.project.importSVG filename, (item) ->
      item.set options
      return
  else
    console.log 'IMPLEMENTATION JSON IMPORT'
  return

CanvasUtil.setStyle = (elements, style)->  
  _.each elements, (e)->
    my_style = _.clone(style)
    if e.className == "Path"
      my_style.strokeColor = style.color
      if e.closed
        my_style.fillColor = style.color
        
    else
      my_style.fillColor = style.color
      
    if e.className == "Path"
      e.set my_style
    else CanvasUtil.setStyle(e.children, style)
  


CanvasUtil.getLEDS = (diffuser) ->
  leds = CanvasUtil.queryPrefix('NLED')
  leds = _.filter(leds, (led) ->
    diffuser.contains led.position
  )
  leds

CanvasUtil.getDiffusers = (led) ->
  diffs = CanvasUtil.queryPrefix('DDS')
  diffs = _.filter(diffs, (diff) ->
    diff.contains led.position
  )
  diffs

CanvasUtil.getMediums = ->
  reflectors = CanvasUtil.queryPrefix('REF')
  lenses = CanvasUtil.queryPrefix('LENS')
  diffusers = CanvasUtil.queryPrefix('DIFF')
  _.each diffusers, (el) ->
    el.optic_type = 'diffuser'
    el.reflectance = 0.3
    el.refraction = 0.8
    # el.probability = 0.5;
    el.n = parseFloat(CanvasUtil.getName(el))
    return
  _.each reflectors, (el) ->
    el.optic_type = 'reflector'
    el.reflectance = 0.9
    return
  _.each lenses, (el) ->
    el.optic_type = 'lens'
    el.refraction = 0.80
    el.n = parseFloat(CanvasUtil.getName(el))
    return
  _.flatten [
    lenses
    reflectors
    diffusers
  ]

CanvasUtil.export = (filename) ->
  console.log 'Exporting SVG...', filename
  prev_zoom = paper.view.zoom
  paper.view.zoom = 1
  paper.view.update()
  exp = paper.project.exportSVG(
    asString: true
    precision: 5)
  saveAs new Blob([ exp ], type: 'application/svg+xml'), filename + '.svg'
  paper.view.zoom = prev_zoom
  paper.view.update()
  return

CanvasUtil.fitToViewWithZoom = (element, bounds, position) ->
  position = position or paper.view.center
  scaleX = element.bounds.width / bounds.width
  scaleY = element.bounds.height / bounds.height
  scale = _.max([
    scaleX
    scaleY
  ])
  console.log 'SET ZOOM TO', scale, bounds.width, bounds.height, 'for', element.bounds.width, element.bounds.height
  paper.view.zoom = 1 / scale
  paper.view.center = position
  return

CanvasUtil.getIDs = (arr) ->
  _.chain(arr).map((el) ->
    CanvasUtil.query paper.project, id: el
  ).flatten().compact().value()

CanvasUtil.getIntersections = (el, collection) ->
  hits = _.map collection, (c) ->
    if _.contains ["Group", "CompoundPath"], c.className
      hit = _.map c.children, (child)->
        CanvasUtil.getIntersections(child, [el])
    else
      hit = c.getIntersections el

  hits = _.compact(hits)
  hits = _.flatten(hits)
  hits
CanvasUtil.getIntersectionsBounds = (el, collection) ->
  hits = _.map collection, (c) ->
    r = new paper.Path.Rectangle(c.bounds)
    ixts = r.getIntersections el
    return if ixts.length > 0 then [{path: c}] else []

  hits = _.compact(hits)
  hits = _.flatten(hits)
  hits

CanvasUtil.query = (container, selector) ->
  `var prefixes`
  # Prefix extension
  if 'prefix' of selector
    prefixes = selector['prefix']

    selector['name'] = (item) ->
      p = CanvasUtil.getPrefixItem(item)
      prefixes.indexOf(p) != -1

    delete selector['prefix']
  else if 'pname' of selector
    prefixes = selector['pname']

    selector['name'] = (item) ->
      p = CanvasUtil.getNameItem(item)
      prefixes.indexOf(p) != -1

    delete selector['pname']
  elements = container.getItems(selector)
  elements = _.map(elements, (el, i, arr) ->
    if el.className == 'Shape'
      nel = el.toPath(true)
      el.remove()
      nel
    else
      el
  )
  elements

CanvasUtil.queryName = (selector) ->
  CanvasUtil.query paper.project, pname: [ selector ]

CanvasUtil.queryPrefix = (selector) ->
  CanvasUtil.query paper.project, prefix: [ selector ]

CanvasUtil.queryPrefixIn = (sub, selector) ->
  CanvasUtil.query sub, prefix: [ selector ]

CanvasUtil.queryIDs = (selector) ->
  _.map selector, (id) ->
    CanvasUtil.queryID id

CanvasUtil.queryID = (selector) ->
  result = CanvasUtil.query(paper.project, id: selector)
  if result.length == 0 then null else result[0]

CanvasUtil.queryPrefixWithId = (selector, id) ->
  _.where CanvasUtil.queryPrefix(selector), lid: id

CanvasUtil.set = (arr, property, value) ->
  if typeof property == 'object'
    _.each arr, (el) ->
      for k of property
        `k = k`
        value = property[k]
        el[k] = value
      return
  else
    _.each arr, (el) ->
      el[property] = value
      return
  return

CanvasUtil.call = (collection, calling, args) ->
  _.each collection, (rt) ->
    if args
      rt[calling](args)
    else
      rt[calling]()
    return
  return

CanvasUtil.getPrefix = (item) ->
  if _.isUndefined(item)
    return ''
  if _.isUndefined(item.name)
    return ''
  # if(item.name.split(":").length < 2) return "";
  if item.name.split(':').length < 2
    return ''
  item.name.split(':')[0].trim()

CanvasUtil.getPrefixItem = (item) ->
  if _.isUndefined(item)
    return ''
  if _.isNull(item)
    return ''
  if item.split(':').length < 2
    return ''
  item.split(':')[0].trim()

CanvasUtil.getName = (item) ->
  if _.isUndefined(item)
    return ''
  if _.isUndefined(item.name)
    return ''
  if item.name.split(':').length < 2
    return ''

  name = item.name.split(':')
  name = name.slice(1).join(':').trim()
  name = name.replaceAll("_x5F_", "_")
  name = name.replaceAll("_x23_", "#")
  name = name.replaceAll("_x27_", "")
  name = name.replaceAll("_x22_", '"')
  name = name.replaceAll("_x7B_", '{')
  name = name.replaceAll("_x7D_", '}')
  name = name.replaceAll("_x5B_", '[')
  name = name.replaceAll("_x5D_", ']')
  name = name.replaceAll("_x2C_", ',')
  name = name.replaceAll("_", ' ')
  if name[0] == "_" then name = name.slice(1)
  if name[name.length - 1] == "_" then name = name.slice(0, -3) #NEEDS TO BE _X_ matched
  if name[name.length - 1] == "_" then name = name.slice(0, -1) #NEEDS TO BE _X_ matched
  
  name
  # x5F__x7B__x22_colorID_x22_
# _{"colorID":[0.90196,0.09804,0.09804],"target":43,"forceTarget":38}

CanvasUtil.getNameItem = (item) ->
  if _.isUndefined(item)
    return ''
  if item.split(':').length < 2
    return ''
  item.split(':')[1].trim()

# ---
# generated by js2coffee 2.2.0