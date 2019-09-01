paper.Path.Arrow = (op)->
  ui_layer.activate()
  arrow = new paper.Group
    name: "arrow"
    extended: false
    smooth: ()->
      this.children.arrowbody.smooth()
      this.children.arrowbody.simplify()

    extend: (boundary)->
      console.log "EXTENDING"
      if this.extended then return
      this.extended = true

      spine = this.children.arrowbody.clone()
      spine.parent = this
      spine.name = "mat"
      spine.set
        strokeWidth: 2
        strokeColor: "#00A8E1"
        dashArray: [10, 4]

      cut = _.map spine.segments, (s, i)->
        return if not boundary.contains(s.point) then i else 1000000
      cut = _.min cut
      if cut < 100000
        spine.removeSegments(cut , spine.segments.length)
        ixts = spine.getIntersections(boundary)
        if ixts.length > 0
          spine.lastSegment.remove()
          spine.addSegment ixts[0].point
      if spine.length < 5 
        console.warn "SPINE LENGTH < 5"
        if this.children.arrowbody
          this.children.arrowbody.remove()
        if this.children.arrowbody
          this.children.arrowhead.remove()
        if spine
          spine.remove()
        this.remove()
        return
      # HEAD
      n2 = spine.getPointAt(spine.length-1)
      n1 = spine.getPointAt(spine.length-5)
      n = n2.subtract(n1)
      n.length = 1000000
      head_n = n
      spine.addSegment n2.add(n)
      ixts = spine.getIntersections(boundary)
      spine.lastSegment.point = ixts[0].point.clone()
      spine.lastSegment.clearHandles()
      # # TAIL
      n2 = spine.getPointAt(1)
      n1 = spine.getPointAt(5)
      n = n2.subtract(n1)
      n.length = 1000000
      spine.insertSegment(0, n2.add(n))
      ixts = spine.getIntersections(boundary)
      spine.firstSegment.remove()
      spine.insertSegment(0, ixts[0].point.clone())

      # c.position = spine.lastSegment.point.clone()
      # n = spine.getPointAt(spine.length - 1).subtract(spine.getPointAt(spine.length - 5))
      # c.rotation = n.angle - 90
      if this.children.arrowbody
        this.children.arrowbody.remove()
      if this.children.arrowhead
        this.children.arrowhead.remove()
      spine.smooth()
      spine.simplify()

      return spine

    addPoint: (pt)->
      p = this.children.arrowbody
      h = this.children.arrowhead
      # console.log "PH", p, h
      if not p then return
      p.addSegment(pt)
      if h
        if p and p.length > 10
          n = p.getNormalAt(p.length - 9)
          h.position = pt
          h.rotation = n.angle 
      else
        if p and p.length > 10
          n = p.getNormalAt(p.length - 9)
          c = new paper.Group
            parent: this
            name: "arrowhead"
            applyMatrix: false
          a = new paper.Path
            parent: c
            strokeWidth: p.strokeWidth
            strokeColor: p.strokeColor
            segments: [new paper.Point(10, -10), new paper.Point(0, 0), new paper.Point(-10, -10)]
            radius: p.strokeWidth
          a.scaling = new paper.Size(op.headScale, op.headScale)
          if op.arrowHead == "solid"
            a.set
              closed: true
              fillColor: p.strokeColor
          c.pivot = a.segments[1].point
          c.position = pt
          c.rotation = n.angle
  arrow.set op
  p = new paper.Path
    name: "arrowbody"
    parent: arrow
    strokeColor: op.arrowColor
    strokeWidth: op.arrowWidth
 
  
  return arrow
