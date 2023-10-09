import "mathUtil"
import "stringUtil"

// Use via
// ```
// import "Graph"
// ...
// graph = Graph.make(...) // Put arguments instead of ...
// ```
Graph = {}

// Creates a new graph
// @param {PixelDisplay} display - pixel display to draw on
// @param {Point2} anchor - bottom left corner of a graph display, in [x, y] form
// @param {Point2} size - size of a graph display, in [x, y] form
// @param {Point2} rangeX - range of a X axis of the graph, in [min, max] form
// @param {Point2} rangeY - range of a Y axis of the graph, in [min, max] form
Graph.make = function(display, anchor, size, rangeX, rangeY)
    if not display isa PixelDisplay then
        throw "`display` parameter must be a PixelDisplay"
    end if
    graph = new Graph
    graph.display = display
    graph.rangeX = getMinMax(rangeX)
    graph.rangeY = getMinMax(rangeY)

    anchor = getXY(anchor)
    size = getXY(size)

    graph.width = size[0]
    graph.height = size[1]

    graph.left = anchor[0]
    graph.right = graph.left + graph.width
    graph.bottom = anchor[1]
    graph.top = graph.bottom + graph.height

    rangeXTotal = graph.rangeX[1] - graph.rangeX[0]
    rangeYTotal = graph.rangeY[1] - graph.rangeY[0]

    graph.scaleX = graph.width / rangeXTotal
    graph.scaleY = graph.height / rangeYTotal

    return graph
end function

// Draws a grid on a graph
// @param {Point2} gridStep - step of a grid cells, can either be one number of an [x, y] list
// @param {Color} [gridColor=color.gray] - optional grid color. Defaults to color.gray
// @param {Color} [textColor=color.aqua] - optional text color. Defaults to color.aqua. Setting this to `color.clear` will disable grid labels
Graph.grid = function(self, gridStep, gridColor = null, textColor = null)
    if gridColor == null then
        gridColor = color.gray
    end if
    if textColor == null then
        textColor = color.aqua
    end if
    gridStep = getXY(gridStep)

    gridStepX = gridStep[0]
    gridStepY = gridStep[1]

    rangeX = self.rangeX
    rangeY = self.rangeY

    scaleX = self.scaleX
    scaleY = self.scaleY

    bottom = self.bottom
    top = self.top
    left = self.left
    right = self.right

    display = self.display

    firstGridLineX = ceil(self.rangeX[0] / gridStepX) * gridStepX
    firstGridLineY = ceil(self.rangeY[0] / gridStepY) * gridStepY

    for gridX in range(firstGridLineX, rangeX[1], gridStepX)
        x = left + (gridX - rangeX[0]) * scaleX
        if abs(gridX) < 1e-6 then
            display.line x, bottom, x, top - 1, gridColor, 4
        else
            display.line x, bottom, x, top, gridColor
        end if
        if textColor != color.clear then
            display.print "" + gridX, x, bottom, textColor, "small"
        end if
    end for
    for gridY in range(firstGridLineY, rangeY[1], gridStepY)
        y = bottom + (gridY - rangeY[0]) * scaleY
        if abs(gridY) < 1e-6 then
            display.line left, y, right, y, gridColor, 4
        else
            display.line left, y, right, y, gridColor
        end if

        if textColor != color.clear then
            display.print "" + gridY, left, y, textColor, "small"
        end if
    end for
    return self
end function

// Adds border to a graph
// @param {Color} [borderColor=color.green] - Border color. Defaults to color.green
// @param {number} [thickness=1] - Border thickness
Graph.border = function(self, borderColor = null, thickness = 1)
    if borderColor == null then
        borderColor = color.green
    end if

    self.display.drawRect self.left, self.bottom, self.width, self.height, borderColor, thickness
    return self
end function

// Plots a function on a graph
// @param {(number) => number} f - function to plot
// @param {Range} [domain] - domain of x values to plot. Defaults to unlimited
// @param {Color} [plotColor=color.red] - Graph line color. Defaults to color.red
// @param {number} [thickness=2] - Graph line thickness
Graph.plot = function(f, domain = null, plotColor = null, thickness = 2)
    if not @f isa funcRef then
        throw "argument `f` of a plot function must be a funcRef"
    end if

    if plotColor == null then
        plotColor = color.red
    end if

    rangeX = self.rangeX
    rangeY = self.rangeY

    scaleX = self.scaleX
    scaleY = self.scaleY

    bottom = self.bottom
    top = self.top
    left = self.left
    right = self.right

    display = self.display

    if domain == null then
        vDomain = [left, right]
        domain = [-1 / 0, 1 / 0]
    else
        domain = getMinMax(domain)
        vDomain = [mathUtil.clamp(left + (domain[0] - rangeX[0]) * scaleX, left, right), mathUtil.clamp(left + (domain[1] - rangeX[0]) * scaleX, left, right)]
    end if
    lastY = null
    drawTop = top - 1
    drawBottom = bottom + 1
    for vx in range(vDomain[0], vDomain[1])
        x = (vx - left) / scaleX + rangeX[0]
        if x < domain[0] then
            x = domain[0]
        else if x > domain[1] then
            x = domain[1]
        end if
        y = f(x)
        vy = bottom + (y - rangeY[0]) * scaleY

        if lastY != null then
            if vy > drawTop or vy < drawBottom then
                if lastY >= drawBottom and lastY <= drawTop then
                    dy = mathUtil.clamp(vy, drawBottom, drawTop)
                    display.line vx - 1, lastY, vx, dy, plotColor, thickness
                end if
            else
                dLastY = mathUtil.clamp(lastY, drawBottom, drawTop)
                display.line vx - 1, lastY, vx, vy, plotColor, thickness
            end if
        end if

        lastY = vy
    end for
    return self
end function

// Draws a point with a label on a graph
// @param {Point2} point - point to draw
// @param {string} [label] - label to draw. Defaults to point coordinates. If empty string is passed, label is not drawn
// @param {Color} [plotColor=color.orange] - Point and label color. Defaults to color.orange
// @param {number} [radius=3] - Radius of a point, defaults to 3. Set it to 0 to only render a label without a point
Graph.drawPoint = function(self, point, label = null, pointColor = null, radius = 3)
    xy = getXY(point)
    if not self.contains(xy) then return self
    point = self.graphToScreen(xy)
    if pointColor == null then
        pointColor = color.orange
    end if
    if label != "" then
        if label == null then
            label = "{0}; {1}".fill(xy)
        end if
        textWidth = label.len * 8 + 1
        textHeight = 14
        ox = point[0]
        oy = point[1]
        if ox + textWidth > self.right then
            ox = self.right - textWidth
        end if
        if oy + textHeight > self.top then
            oy = self.top - textHeight
        end if
        self.display.fillRect ox, oy, textWidth, textHeight, pointColor
        self.display.print label, ox, oy, color.black, "small"
    end if
    if pointColor != color.clear and radius != 0 then
        self.display.fillEllipse point[0] - radius, point[1] - radius, radius * 2, radius * 2, pointColor
        self.display.drawEllipse point[0] - radius - 1, point[1] - radius - 1, radius * 2 + 2, radius * 2 + 2, color.black
    end if
    return self
end function

// Checks if point is inside graph bounds
// @param {Point2} point - point to check for
Graph.contains = function(self, point)
    xy = getXY(point)
    rangeX = self.rangeX
    rangeY = self.rangeY
    return rangeX[0] <= xy[0] <= rangeX[1] and rangeY[0] <= xy[1] <= rangeY[1]
end function

// Converts graph point to screen point
// @param {Point2} point - graph point to convert
Graph.graphToScreen = function(self, point)
    point = getXY(point)
    return [
      self.left + (point[0] - self.rangeX[0]) * self.scaleX,
      self.bottom + (point[1] - self.rangeY[0]) * self.scaleY,
    ]
end function

// Converts screen point to graph point
// @param {Point2} point - screen point to convert
Graph.screenToGraph = function(self, point)
    point = getXY(point)
    return [
      (point[0] - self.left) / self.scaleX + self.rangeX[0],
      (point[1] - self.bottom) / self.scaleY + self.rangeY[0],
    ]
end function

// Exports graph as an {Image}
Graph.image = function(self)
    return self.display.getImage(self.left, self.bottom, self.width, self.height)
end function

// #region Utility functions

throw = function(msg)
    oldColor = text.color
    text.color = color.red
    pprint msg
    text.color = oldColor
    exit
end function

getXY = function(argument)
    if argument isa list then
        return [argument[0], argument[1]]
    else if argument isa map then
        return [argument.x, argument.y]
    else if argument isa number then
        return [argument, argument]
    else
        throw "Can't extract XY from an argument: " + argument
    end if
end function

getMinMax = function(argument)
    if argument isa list then
        return [argument[0], argument[1]]
    else if argument isa map then
        return [argument.min, argument.max]
    else
        throw "Can't extract min/max from an argument: " + argument
    end if
end function

// #end region

return Graph