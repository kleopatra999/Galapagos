if not window.AgentModel?
  console.log('view.js requires agentmodel.js!')

class window.AgentStreamController
  constructor: (@container) ->
    @turtleView = new TurtleView()
    @patchView = new PatchView()
    @layeredView = new LayeredView()
    @layeredView.setLayers(@patchView, @turtleView)
    @container.appendChild(@layeredView.canvas)
    @model = new AgentModel()
    @repaint()

  repaint: ->
    @turtleView.repaint(@model.world, @model.turtles)
    @patchView.repaint(@model.world, @model.patches)
    @layeredView.repaint()

  update: (modelUpdate) ->
    @model.update(modelUpdate)

class View
  constructor: () ->
    @canvas = document.createElement('canvas')
    @canvas.width = 500
    @canvas.height = 500
    @canvas.style.width = "100%"
    @ctx = @canvas.getContext('2d')

  matchesWorld: (world) ->
    (@maxpxcor? and @minpxcor? and @maxpycor? and @minpycor? and @patchsize?) and
      (not world.maxpxcor? or world.maxpxcor == @maxpxcor) and
      (not world.minpxcor? or world.minpxcor == @minpxcor) and
      (not world.maxpycor? or world.maxpycor == @maxpycor) and
      (not world.minpycor? or world.minpycor == @minpycor) and
      (not world.patchsize? or world.patchsize == @patchsize)

  transformToWorld: (world) ->
    @maxpxcor = if world.maxpxcor? then world.maxpxcor else 25
    @minpxcor = if world.minpxcor? then world.minpxcor else -25
    @maxpycor = if world.maxpycor? then world.maxpycor else 25
    @minpycor = if world.minpycor? then world.minpycor else -25
    @patchsize = if world.patchsize? then world.patchsize else 9
    @patchWidth = @maxpxcor - @minpxcor + 1
    @patchHeight = @maxpycor - @minpycor + 1
    @canvas.width =  @patchWidth * @patchsize
    @canvas.height = @patchHeight * @patchsize
    # Argument rows are the matrix columns. See spec.
    @ctx.setTransform(@canvas.width/@patchWidth, 0,
                      0, -@canvas.height/@patchHeight,
                      -(@minpxcor-.5)*@canvas.width/@patchWidth,
                      (@maxpycor+.5)*@canvas.height/@patchHeight)

class LayeredView extends View
  setLayers: (layers...) ->
    @layers = layers
  repaint: () ->
    @canvas.width = Math.max((l.canvas.width for l in @layers)...)
    @canvas.height = Math.max((l.canvas.height for l in @layers)...)
    for layer in @layers
      @ctx.drawImage(layer.canvas, 0, 0)
    return

class TurtleView extends View
  constructor: () ->
    super()
    @drawer = new CachingShapeDrawer()

  drawTurtle: (id, turtle) ->
    xcor = turtle.xcor or 0
    ycor = turtle.ycor or 0
    heading = turtle.heading or 0
    scale = turtle.size or 1
    angle = (180-heading)/360 * 2*Math.PI
    shapeName = turtle.shape
    shape = shapes[shapeName] or shapes.default
    @ctx.save()
    @ctx.translate(xcor, ycor)
    if shape.rotate
      @ctx.rotate(angle)
    else
      @ctx.rotate(Math.PI)
    @ctx.scale(scale, scale)
    @drawer.drawShape(@ctx, turtle.color, shapeName)
    @ctx.restore()

  repaint: (world, turtles) ->
    @transformToWorld(world)
    @ctx.lineWidth = .1
    @ctx.fillStyle = 'red'
    for id, turtle of turtles
      @drawTurtle(id, turtle)
    return

class PatchView extends View
  constructor: () ->
    super()
    @patchColors = []

  transformToWorld: (world) ->
    super(world)
    @patchColors = []
    for x in [@minpxcor..@maxpxcor]
      for y in [@maxpycor..@minpycor]
        @colorPatch({'pxcor': x, 'pycor': y, 'pcolor': 'black'})
      col = 0
    return

  colorPatch: (patch) ->
    row = patch.pxcor-@minpxcor
    col = @maxpycor - patch.pycor
    patchIndex = row*@patchWidth + col
    color = patch.pcolor
    if typeof(color) == 'number'
      color = netlogoColorToCSS(color)
    if color != @patchColors[patchIndex]
      @patchColors[patchIndex] = @ctx.fillStyle = color
      @ctx.fillRect(patch.pxcor-.5, patch.pycor-.5, 1, 1)

  repaint: (world, patches) ->
    if not @matchesWorld(world)
      @transformToWorld(world)
    for _, p of patches
      @colorPatch(p)