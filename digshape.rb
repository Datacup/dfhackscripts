# dig shapes
=begin

digshape
=======
digshape allows the creation of a number of repetative geometric designations. The script can be called manually, or through gui/digshape.

Commands that do not require a set origin:

    To dig a 3x3 sparse up-down stairway:
        digshape downstair <depth>
    
    To undo the previous command (restoring designation): digshape undo

    To flood fill with a designation, overwriting ONLY the designation under the cursor:
            digshape flood

Commands that require an origin to be set:

    To set the origin for drawing:
        digshape origin

    To draw to the cursor:
        digshape line
    
    To draw an ellipse using the origin and target as a bounding box:
        digshape ellipse (filled? [default: false])
    
    To draw an ellipse using the origin and target as a major axis, and the cursor as the length of the semiminor axis (aka width [dist from cursor to line]):
        digshape major (to set the major axis endpoint [the length])
        digshape ellipse3p
    
    To draw a circle using an arbitrary diameter (gives slightly different results to digcircle):
        digshape circle2p
    
    To draw a 3 pt bezier curve, with an arbitrary float for weighting the sharpness:
        digshape major (to set the end point of the curve)
        digshape bez [sharpness=1.5]
      
    To draw a polygon using the origin as the center and the cursor as the radius|apothem (radius)
        digshape polygon <sides> [radius|apothem] [digMode]

    To draw a star using the origin as the center and the cursor as the radius|apothem (radius)
            digshape star <points> [skip] [digMode]

    To draw an Archimedean spiral (coils - number of coils, chord - distance between points):
        digshape spiral <coils> <chord>

    To move all of the markers to the current z level:
        digshape resetz

    All commands accept a digging designation mode as a single character argument [dujihrx], otherwise will default to 'd'
=end






=begin
============  SCRIPT DESCRIPTION  ============
Digshape operates directly on the current mapstate. An undo buffer is maintained for the last-run command, and for the markers.

This file is broken into segments.
=GUI interfacing
    code required to allow headless operation through gui/digshape.

=Utility functions
    generic helper functions for script

=Data structures
    structure to hold coordinates, and to interpret the designations.

=Cursor functions
    code to interact with the map (df(hack)). Get, set, undo.

=Shape functions
    functions to draw geometries.

=Script control
    print help, functions to parse arguments, untap, upkeep.

=Commands
    user-callable interactions with digshape. Each command is responsible for getting arguments it needs, calling the functions to make it's geometry, and plotting them to the map (frequently a side-effect of the geometry function).

============  KNOWN BUGS  ============
    BUG: "digshape polygon 3 r" uses both 'radius' and digmode:'r'
    BUG: "digshape polygon 2 apothem" does not work, but higher numbers do.



============  TODO  ============
    TODO: mark origin should not change the digging designation, ellipse cleanup should restore not clear it.
    TODO: replace text dig designations with dfhack enums
    TODO: convert digshape to lua script
    TODO: just always use the current Z level. (ensure undo)
    TODO: rename control points to A,B,C,... for more generality and faster discussion. Maybe origin+ABCD...? [Origin, Cursor, A,B,C,D,...]
    TODO: add marker mode/toggle marker designation, smooth, engrave, carveFortification




============  FEATURE IDEAS  ============
    IDEA: Pixel fonts (size)
    IDEA: Gradient fill. (2pt box, 1pt midpoint, arg: direction[NSEW,diags,star,pit,rings,etc])
    IDEA: 3d shapes (eg platonic solids)

    IDEA: circle3p (given any 3p)  (((Ali Sheikhpour (https://math.stackexchange.com/users/707123/ali-sheikhpour), Get the equation of a circle when given 3 points, URL (version: 2021-01-26): https://math.stackexchange.com/q/4000949)))
    IDEA: arc 3p (as circle3p but only draw inside bbox)
    IDEA: default digmode is whatever is selected currently in the active df:designationMode screen
    IDEA: add diagonal adjacency to floodfill as an option
=end








=begin
========================  DIGSHAPE GUI interfacing
really nasty hack so that lua can use digshape.

GUI allows for 'preview' which returns the points digshape would dig, but does not modify the map. Printing and errors are redirected.
=end

$isLuaMode = $script_args[0] == "lua"
$isPreviewOnly = false

if $isLuaMode then
    $script_args.delete_at(0)
    $isPreviewOnly = $script_args[0] == "preview"
    if $isPreviewOnly then
        $script_args.delete_at(0)
    end
    $output
end

def writeLuaPos(name, digPos) # pos:<name>:<X>:<Y>:<Z>
    if $isLuaMode then
        puts "pos:#{name}:#{digPos.to_s}"
    end
end






=begin
========================  UTILITY FUNCTIONS
=end


def stdout(msg)
    # print a message to the console
    if $isLuaMode == false then
        puts msg
    else
        puts "msg:"+msg
    end
end

def stderr(msg)
    # print an error message to the console
    if $isLuaMode == false then
        puts "  Error: "+msg
    else
        puts "err:"+msg
    end
end

def scriptError(msg)
    # call this when you reach corner cases / the fault perhaps isn't the user. Script terminates.
    stderr(msg)
    raise "oopsie! script errored! ;)"
end

def userSucks(msg)
    # call this when we don't like the user's input. Script may continue.
    stderr(msg)
    throw :script_finished
end









=begin
========================  DATA STRUCTURES
=end


DigPos = Struct.new(:x, :y, :z) do
    #Holds a 3d coordinate
    def to_s
      return "(#{x},#{y},#{z})"
    end
    def clone
        return DigPos.new(x,y,z)
    end
end

#Control points:
    #$origin
    #$major
    #$cursor

def clearDigBuffer()
    #$digBuffer* is a set of global arrays containing the 3d coordinates and their prior dig designations.

    #clear buffer for next dig, or initialize if empty.
    $digBufferX=[]
    $digBufferY=[]
    $digBufferZ=[]
    $digBufferD=[]
end


def getDigMode(digMode = 'd')
#TODO just integrate this into getDigModeArgument.
    if ['d', 'u', 'j', 'i', 'h', 'r', 'x'].include? digMode then
        return digMode
    end
    return 'd'
end


def digMode2enum(digMode)
    #this function turns a digmode into the appropriate enum for easier comparison on tile reading (eg floodfill.)
    case digMode #from https://github.com/DFHack/scripts/blob/master/digfort.rb
        when 'd'; return :Default
        when 'u'; return :UpStair
        when 'j'; return :DownStair
        when 'i'; return :UpDownStair
        when 'h'; return :Channel
        when 'r'; return :Ramp
        when 'x'; return :No
        else
            scriptError("Unknown digMode, `"+digMode+"', digMode must be any of 'd', 'u', 'j', 'i', 'h', 'r', or 'x', which correspond to the designation keys")
    end
end


def enum2digMode(digEnum)
    #this function turns a designation enum into the appropriate digtype character
    case digEnum #from https://github.com/DFHack/scripts/blob/master/digfort.rb
        when :Default; return 'd'
        when :UpStair; return 'u'
        when :DownStair; return 'j'
        when :UpDownStair; return 'i'
        when :Channel; return 'h'
        when :Ramp; return 'r'
        when :No; return 'x'
        else
            scriptError("Unknown digEnum `#{digEnum.to_s}'")
    end
end




=begin
========================  CURSOR FUNCTIONS
=end


def cursorAsDigPos()
    #returns current cursor position as a DigPos
    return DigPos.new(df.cursor.x, df.cursor.y, df.cursor.z)
end




def setOrigin(x, y, z)
    # sets the origin and marks if it iff we are in console. cleans up last mark too.
    #TODO: make 'controlpoints' an array indexed by name, so that all can be operated on in the same way.
    $origin = DigPos.new(x,y,z)
    # the rest is just really complicated logic to mark the origin if the user is using the console version
    # it also has to play well with lua

    if $oldOrigin then
        oldTile = df.map_tile_at($oldOrigin.x, $oldOrigin.y, $oldOrigin.z)
        oldTile.dig($oldOriginDesignation) if oldTile.shape_basic == $oldOriginShape && oldTile.designation.dig == digMode2enum('d')
    end
    if not $isLuaMode then
        $oldOrigin = $origin.clone()
        newOriginTile = df.map_tile_at($origin.x, $origin.y, $origin.z)
        $oldOriginDesignation = newOriginTile.designation.dig
        $oldOriginShape = newOriginTile.shape_basic

        digAt($origin.x, $origin.y, $origin.z, 'd', buffer: false) 
    else
        $oldOrigin = nil # don't undo our origins if we are in lua mode
    end
end

def setMajor(x, y, z)
    # Assigns the control point 'major' to the current cursor location
    $major = DigPos.new(x,y,z)
end



def undo()
    #Execute one level of undo.
    #z level is presumed to be the current.
    #BUG: Does not keep track of Z levels
    #TODO: have multiple levels of undo / redo
    i=$digBufferX.length
    newBufferX = []
    newBufferY = []
    newBufferZ = [] # redundant, i.e. always the same most of the time, but needed so that we use it as a pointer for digAt. Also supports digging multi dimenisional shapes
    newBufferD = []
    while i > 0 do
        x=$digBufferX.pop
        y=$digBufferY.pop
        z=$digBufferZ.pop
        d=$digBufferD.pop
        digAt(x,y,z, enum2digMode(d), buffer: true, bufferX: newBufferX, bufferY: newBufferY, bufferZ: newBufferZ, bufferD: newBufferD)
        i = i-1
    end
    #clear buffer for next dig
    $digBufferX = newBufferX
    $digBufferY = newBufferY
    $digBufferZ = newBufferZ
    $digBufferD = newBufferD
end


def isDigPermitted(digMode, tileShape)
    # can we dig on this tile?
    
    if not tileShape then return false end
    
    case digMode
        when 'd', 'u', 'i', 'r'; return tileShape == :Wall
        when 'j', 'h'; return tileShape == :Wall || tileShape == :Floor
        when 'x'; return true
        else
            scriptError("Unknown digMode: `"+digMode+"'")
    end
end

def digAt(x, y, z, digMode = 'd', buffer: true, bufferX: $digBufferX, bufferY: $digBufferY, bufferZ: $digBufferZ, bufferD: $digBufferD)
    #Commit designation@coords to the map, opt save current value there to the buffer for undo.

    tile = df.map_tile_at(x, y, z)

    # check if the tile returned is valid, ignore if its not (out of bounds, air, etc)
    if tile then
        tileShape = tile.shape_basic

        if isDigPermitted(digMode, tileShape) then
            if $isPreviewOnly then
                puts "dig:"+digMode+":"+x.to_s+":"+y.to_s+":"+z.to_s
            else
                if buffer then # store the current tile's designation in a undo buffer
                    bufferX.push(x)
                    bufferY.push(y)
                    bufferZ.push(z)
                    bufferD.push(tile.designation.dig)
                    
                end
                tile.dig(digMode2enum(digMode))
            end
        end
    end
end







=begin
========================  SHAPES FUNCTIONS
=end


def drawLineLow(x0, y0, z0, x1, y1, z1, digMode = 'd')
    # Helper function for drawLine.
    # Uses: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
    dx = x1 - x0
    dy = y1 - y0
    yi = 1
    if dy < 0 then
        yi = -1
        dy = -dy
    end

    d = 2*dy - dx
    y = y0

    x = x0
    while x <= x1
        digAt(x, y, z0, digMode)
        if d > 0 then
            y = y + yi
            d = d - 2*dx
        end
        d = d + 2*dy
        x += 1
    end
end

def drawLineHigh(x0, y0, z0, x1, y1, z1, digMode = 'd')
    # Helper function for drawLine.
    # Uses: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
    dx = x1 - x0
    dy = y1 - y0
    xi = 1
    if dx < 0 then
        xi = -1
        dx = -dx
    end
    d = 2*dx - dy
    x = x0

    y = y0
    while y <= y1
        digAt(x, y, z0, digMode)
        if d > 0 then
            x = x + xi
            d = d - 2*dy
        end
        d = d + 2*dx
        y += 1
    end
end

def drawLine(x0, y0, z0, x1, y1, z1, digMode = 'd')
    # Draw a straight, line between two points.
    # Uses: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
    if (y1 - y0).abs < (x1 - x0).abs then
        if x0 > x1 then
            drawLineLow(x1, y1, z1, x0, y0, z0, digMode)
        else
            drawLineLow(x0, y0, z0, x1, y1, z1, digMode)
        end
    else
        if y0 > y1 then
            drawLineHigh(x1, y1, z1, x0, y0, z0, digMode)
        else
            drawLineHigh(x0, y0, z0, x1, y1, z1, digMode)
        end
    end
end

def plotQuadRationalBezierSeg(x0, y0, z0, x1, y1, z1, x2, y2, z2, w, digMode = 'd')
    # Helper function for plotQuadRationalBezier, draws one portion of the curve.

=begin
    /* plot a limited rational Bezier segment, squared weight */
    Source: http://members.chello.at/easyfilter/bresenham.pdf listing 12
    #p0:origin, p1:weight, p2:termination
    #w is the weighting. "For w =1 the curve is a parabola, for w < 1 the curve is an ellipse, for w = 0 the curve is a straight line and for w>1 the curve is a hyperbola. The weights are normally assumed to be all positive."
=end
    x0 = x0.floor  #start with integer locations. Original code stores in int, so this is implicit.
    x1 = x1.floor
    x2 = x2.floor
    y0 = y0.floor
    y1 = y1.floor
    y2 = y2.floor

    sx = x2 - x1 ## relative values for checks */
    sy = y2 - y1
    dx = x0 - x2
    dy = y0 - y2
    xx = x0 - x1
    yy = y0 - y1
    xy = xx * sy + yy * sx
    cur = xx * sy - yy * sx ## curvature */
    
    if (cur != 0.0 && w > 0.0) then 
        ## no straight line */
        if (sx * sx + sy * sy > xx * xx + yy * yy) then 
            ## begin with longer part */
            x2 = x0  ## swap P0 P2 */
            x0 = x0 - dx
            y2 = y0
            y0 = y0 - dy
            cur = -cur
        end
        
        xx = 2.0 * (4.0 * w * sx * xx + dx * dx)  ## differences 2nd degree */
        yy = 2.0 * (4.0 * w * sy * yy + dy * dy)
        
        sx = x0 < x2 ? 1 : -1  #/* x step direction */
        sy = y0 < y2 ? 1 : -1  #/* y step direction */
        xy = -2.0 * sx * sy * (2.0 * w * xy + dx * dy)
        
        if (cur * sx * sy < 0.0) then  
        ## negated curvature? */
            xx = -xx
            yy = -yy
            xy = -xy
            cur = -cur
        end
        
        ## differences 1st degree */
        dx = 4.0 * w * (x1 - x0) * sy * cur + xx / 2.0 + xy  
        dy = 4.0 * w * (y0 - y1) * sx * cur + yy / 2.0 + xy
        
        if (w < 0.5 && dy > dx) then
            ## flat ellipse, algorithm fails */
            cur = (w + 1.0) / 2.0
            w = Math.sqrt(w)
            xy = 1.0 / (w + 1.0)
            
            ## subdivide curve in half */
            sx = ((x0 + 2.0 * w * x1 + x2) * xy / 2.0 + 0.5).floor
            sy = ((y0 + 2.0 * w * y1 + y2) * xy / 2.0 + 0.5).floor
            
            ## plot separately */
            dx = ((w * x1 + x0) * xy + 0.5).floor
            dy = ((y1 * w + y0) * xy + 0.5).floor
            plotQuadRationalBezierSeg(x0, y0, dx, dy, sx, sy, cur)
            
            dx = ((w * x1 + x2) * xy + 0.5).floor
            dy = ((y1 * w + y2) * xy + 0.5).floor
            plotQuadRationalBezierSeg(sx, sy, dx, dy, x2, y2, cur)
            
            #we are finished with plotting by recursion, exit.
            return
        end
        
        err = dx + dy - xy ## error 1.step */

        loop do
            digAt(x0,y0,z0, digMode)  #/* plot curve */

            if (x0.floor == x2.floor && y0.floor == y2.floor) then
                #/* last pixel -> curve finished */
                return  
            end
                
            ## save value for test of x step */
            x1 = 2 * err > dy
            y1 = 2 * (err + yy) < -dy
            
            if (2 * err < dx ||  y1) then
                #xstep
                y0 = y0 + sy
                dy = dy + xy
                dx = dx + xx
                err = err + dx
            end
            
            if (2 * err > dx ||  x1) then
                #y step
                x0 = x0 + sx
                dx = dx + xy
                dy = dy + yy
                err = err + dy
                
            end
            
            if (dy > dx) then
                break ## gradient negates -> algorithm fails */
            end
        end
    end
    
    ## plot remaining needle to end */
    drawLine(x0,y0,z0, x2,y2,z0, digMode)
end

def plotQuadRationalBezier(x0, y0, z0,  x1, y1, z1,  x2, y2, z2,  w=1.5, digMode = 'd')
    #Draw a bezier between origin[p0] and control point[p2], pulled out towards cursor[p1] (by a weighting of 'w')

    # Source: http://members.chello.at/easyfilter/bresenham.pdf listing 11: /* plot any quadratic rational Bezier curve */

    x = x0 - 2 * x1 + x2
    y = y0 - 2 * y1 + y2
    xx = x0 - x1
    yy = y0 - y1
    
    ## horizontal cut at P4? */
    if (xx * (x2 - x1) > 0)  then
    
        ## vertical cut at P6 too? */
        if (yy * (y2 - y1) > 0) then
        
            ## which first? */
            if ((xx * y).abs > (yy * x).abs)  then
                ## swap points */
                x0 = x2
                x2 = xx + x1
                y0 = y2
                y2 = yy + y1
            end 
            ## now horizontal cut at P4 comes first */
        end
        
        if (x0 == x2 || w == 1.0) then
            t = ((x0 - x1) / x.to_f)  #ruby implicitly decides this is an integer and rounds it here without the expicit .to_f on that whole number.
        else
            ## non-rational or rational case */
            q = Math.sqrt(4.0 * w * w * (x0 - x1) * (x2 - x1) + (x2 - x0) * (x2 - x0))
            if (x1 < x0) then
                q = -q
            end
            t = (2.0 * w * (x0 - x1) - x0 + x2 + q) / (2.0 * (1.0 - w) * (x2 -x0))## t at P4 */
        end
        
        q = 1.0 / (2.0 * t * (1.0 - t) * (w - 1.0) + 1.0) ## sub-divide at t */
        xx = (t * t * (x0 - 2.0 * w * x1 + x2) + 2.0 * t * (w * x1 - x0) + x0) * q ## = P4 */
        yy = (t * t * (y0 - 2.0 * w * y1 + y2) + 2.0 * t * (w * y1 - y0) + y0) * q
        ww = t * (w - 1.0) + 1.0
        w = w * ww * q ## squared weight P3 */
        w = ((1.0 - t) * (w - 1.0) + 1.0) * Math.sqrt(q) ## weight P8 */
        x = (xx + 0.5).floor
        y = (yy + 0.5).floor ## P4 */
        yy = (xx - x0) * (y1 - y0) / (x1 - x0) + y0 ## intersect P3 | P0 P1 */
        plotQuadRationalBezierSeg(x0, y0, z0, x, (yy + 0.5).floor, z0, x, y, z0, ww, digMode)
        
        yy = (xx - x2) * (y1 - y2) / (x1 - x2) + y2 ## intersect P4 | P1 P2 */
        y1 = (yy + 0.5).floor
        x0 = x1 = x
        y0 = y ## P0 = P4, P1 = P8 */
    end
    
    if ((y0 - y1) * (y2 - y1) > 0)  then
        ## vertical cut at P6? */
        if (y0 == y2 || w == 1.0) then
            t = (y0 - y1) / (y0 - 2.0 * y1 + y2)
        else
            ## non-rational or rational case */
            q = Math.sqrt(4.0 * w * w * (y0 - y1) * (y2 - y1) + (y2 - y0) * (y2 - y0))
            if (y1 < y0) then
                q = -q
            end
            t = (2.0 * w * (y0 - y1) - y0 + y2 + q) / (2.0 * (1.0 - w) * (y2 - y0)) ## t at P6 */
        end
        
        q = 1.0 / (2.0 * t * (1.0 - t) * (w - 1.0) + 1.0) ## sub-divide at t */
        xx = (t * t * (x0 - 2.0 * w * x1 + x2) + 2.0 * t * (w * x1 - x0) + x0) * q ## = P6 */
        yy = (t * t * (y0 - 2.0 * w * y1 + y2) + 2.0 * t * (w * y1 - y0) + y0) * q
        ww = t * (w - 1.0) + 1.0
        ww = ww * ww * q ## squared weight P5 */
        w = ((1.0 - t) * (w - 1.0) + 1.0) * Math.sqrt(q) ## weight P7 */
        x = (xx + 0.5).floor
        y = (yy + 0.5).floor ## P6 */
        xx = (x1 - x0) * (yy - y0) / (y1 - y0) + x0 ## intersect P6 | P0 P1 */
        plotQuadRationalBezierSeg(x0, y0, z0, (xx + 0.5).floor, y, z0, x, y, z0, ww, digMode)
        
        xx = (x1 - x2) * (yy - y2) / (y1 - y2) + x2 ## intersect P7 | P1 P2 */
        x1 = (xx + 0.5).floor
        x0 = x
        y0 = y1 = y## P0 = P6, P1 = P7 */
    end

    ## plot remaining curve segment remaining */
    plotQuadRationalBezierSeg(x0, y0, z0, x1, y1, z0, x2, y2, z0, w * w, digMode)
end

def plotRotatedEllipse(x, y, z, a, b, angle, digMode='d')
    # Helper function for drawEllipse(). Draw an ellipse(center, major len, minor len) rotated by angle (radian)

=begin
    Source: http://members.chello.at/easyfilter/bresenham.pdf listing 13. Explicitly released without copyright
    Note: most of this function deals with the ellipse at the origin. Translation to coordinates is at final call.
    
    x,y is the coodinates of the center
    a is __SEMI__major length
    b is __SEMI__minor length
    angle (radians), prob measured CCW from east
    
    A far more readable paper on plotting rotated ellipses (no pseudocode): http://www.crbond.com/papers/ell_alg.pdf
    Another paper on rasterizing 2d primitives: https://cs.brown.edu/research/pubs/theses/masters/1989/dasilva.pdf
=end
    angle = -angle #deal with -y axis.
    
    xd = a * a
    yd = b * b
    
    ## ellipse rotation */
    s = Math.sin(angle)
    zd = (xd - yd) * s
    
    ## surrounding rectangle */
    xd = Math.sqrt(xd - zd * s)
    yd = Math.sqrt(yd + zd * s)
    
    ## scale to integer */
    a = xd + 0.5
    b = yd + 0.5
    zd = zd * a * b / (xd * yd)
    
    plotRotatedEllipseRect(x - a, y - b, z,   x + a, y + b,   (4 * zd * Math.cos(angle)), digMode)
end

def plotRotatedEllipseRect(x0, y0, z0, x1, y1, zd, digMode='d')
    #http://members.chello.at/easyfilter/bresenham.pdf listing 13
    #/* rectangle enclosing the ellipse, integer rotation angle */
    #x0,y0 and x1,y1 are a bbox
    #zd is rotation ? probably as 100*angle_in_radians?
    ## rectangle enclosing the ellipse, integer rotation angle */
    
    xd = x1 - x0
    yd = y1 - y0
    w = xd * yd
    
    if (zd == 0)
        #Special case: no rotation. Use standard method. /* looks nicer */
        #this should never be reached, as we call this from the regular ellipse function.
        stdout("zd=0 degenerate case")
        drawEllipse(x0,y0,z0, x1,y1,z0)
        return
    end
    
    ## squared weight of P1 */
    if (w != 0.0) then
        w = (w - zd) / (w + w)
    end
    
    if not(w <= 1.0 && w >= 0.0) then  #/* limit angle to |zd|<=xd*yd */
        scriptError("Limit angle to |zd|<=xd*yd")
    end
     
    ## snap xe,ye to int */
    xd = (xd * w + 0.5).floor
    yd = (yd * w + 0.5).floor
    
    ##plot 4 sub arcs that make the ellipse
    plotQuadRationalBezierSeg(x0, y0 + yd, z0,   x0, y0, z0,   x0 + xd, y0, z0,   1.0 - w, digMode)
    plotQuadRationalBezierSeg(x0, y0 + yd, z0,   x0, y1, z0,   x1 - xd, y1, z0,   w, digMode)
    plotQuadRationalBezierSeg(x1, y1 - yd, z0,   x1, y1, z0,   x1 - xd, y1, z0,   1.0 - w, digMode)
    plotQuadRationalBezierSeg(x1, y1-yd, z0,   x1,y0, z0,   x0+xd,y0, z0,   w, digMode)
end

def drawEllipse(x0, y0, z0, x1, y1, z1, x2=nil, y2=nil, z2=nil, filled = false, digMode = 'd', mode = 'bbox')
    #Draw an ellipse, using the current control points, in the method specified by mode.

=begin
    # A Fast Bresenham Type Algorithm For Drawing Ellipses http://homepage.smc.edu/kennedy_john/belipse.pdf (https://www.dropbox.com/s/3q89g566u115g3q/belipse.pdf?dl=0)
    # also adapted from https://github.com/teichgraf/WriteableBitmapEx/blob/master/Source/WriteableBitmapEx/WriteableBitmapShapeExtensions.cs used under the MIT license
    
    #p0 [xyz]: origin of major axis; OR a corner of bbox
    #p1 [xyz]: termination of major axis; OR the other corner of the bbox
    #p2 [xyz]: the extent (not a point nessisarily on the minor axis..) of the minor _radius_; aka, a point on the bounding box long side that will be used to determine the length of the short side.

    #mode ['bbox']:
        -'diameter': make a circle given 2p as the diameter
        -'axis': make an ellipse along the line [origin, major], with the cursor setting the width. width is the distance from the cursor to the line.
        -'bbox': generate an ellipse to fit entirely within the bounding box of [origin, cursor]
        -IDEA: '5p': given 5p draw an ellipse that fits.
=end

    xl = [x0, x1].min # find left edge
    xr = [x0, x1].max # find right edge
    yb = [y0, y1].min # find lower edge
    yt = [y0, y1].max # find top edge 
    
    #determine if this is an even distance ellipse, which will require special handling as the center is on the vertex of four adjacent squares rather than inside.
    #we will use these to offset part of the ellipse drawing
    if (xl - xr).odd? then xeven = 1 else xeven = 0 end
    if (yt - yb).odd? then yeven = 1 else yeven = 0 end

    # find radius
    xrad = ((xr - xl) / 2).ceil
    yrad = ((yt - yb) / 2).ceil

    # find center
    xc = xl + xrad
    yc = yb + yrad
    
    if mode == 'diameter' then
        if (xl == xr) then
            #If x's equal, this is a vertical designation
            xl -= yrad
            xr += yrad
            xrad = yrad
            elsif (yt==yb)
                #a horizontal designation
                yt += xrad
                yb -= xrad
                yrad = xrad
            else
                #a diagonal designation
                diam = Math.sqrt( (xr-xl)**2 + (yt-yb)**2 )
                rad = (diam/2).floor
                
                xc = ((xl + xr ) / 2).ceil
                yc = ((yt + yb ) / 2).ceil
                
                xl = xc - rad
                xr = xc + rad
                yt = yc + rad
                yb = yc - rad
                
                xrad = yrad = rad
        end
    elsif mode == 'axis' then
        if (xl == xr) then
            #If x's equal, this is a vertical designation origin--major
            #find true x components
            xrad = (x2 - xl).abs
            xtemp = xl
            xl = xtemp + xrad
            xr = xtemp - xrad

        elsif (yt == yb)
            #Horizontal origin--major
            #find true y components
            yrad = (y2 - yt).abs
            ytemp = yt
            yt = ytemp + yrad
            yb = ytemp - yrad
        
        else
            #diagonal axis
            #don't use xl,xr,yt,yb here, we need the points raw.
            #p0: origin,   p1: major axis,    p2: minor axis
            
            radAngle = Math.atan2((y0 - y1), (x1 - x0)) #in radians
            xc = (xl + xr)/2  #center
            yc = (yt + yb)/2
            
            aaxis = Math.sqrt( (y1-y0)**2 + (x1-x0)**2)  #major (a) axis (full diameter)
            #minor axis length: https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Line_defined_by_two_points
            baxis = 2*( (x1-x0) * (y0-y2)  -  (x0-x2) * (y1-y0)).abs / aaxis
            
            #use specific arbitrary ellipse function rather than the easy method.
            plotRotatedEllipse(xc, yc, z0, aaxis/2, baxis/2, radAngle, digMode) #func expects axis lengths as radius (1/2)
            return
        end
    end
    
    #Method for horizontal/vertical ellipses and 2p circles follows:

    # Avoid endless loop
    return if (xrad < 1 || yrad < 1)

    # Init vars
    x = xrad
    y = 0
    xrSqTwo = xrad * xrad * 2
    yrSqTwo = yrad * yrad * 2
    xChg = yrad * yrad * (1 - (xrad * 2))
    yChg = xrad * xrad
    err = 0
    xStopping = yrSqTwo * xrad
    yStopping = 0

    # Draw first set of points counter clockwise where tangent line slope > -1.
    while xStopping >= yStopping
        # Draw 4 quadrant points at once
        if filled then
            #filled ellipse, dig a line across.
            xi = 2 * x  + xeven# loop variable
            while xi >= 0
                digAt(xc - x + xi, yc + y + yeven, z0, digMode)
                digAt(xc - x + xi, yc - y, z0, digMode)
                xi -= 1
            end
        else
            #hollow ellipse
            digAt(xc + x + xeven, yc + y + yeven, z0, digMode)
            digAt(xc - x, yc + y + yeven, z0, digMode)
            digAt(xc - x, yc - y, z0, digMode)
            digAt(xc + x + xeven, yc - y, z0, digMode)
        end

        y+= 1
        yStopping += xrSqTwo
        err += yChg
        yChg += xrSqTwo

        if ((xChg + (err * 2)) > 0) then
            x-= 1
            xStopping -= yrSqTwo
            err += xChg
            xChg += yrSqTwo
        end
    end

    # Draw second set of points clockwise where tangent line slope < -1.

    # ReInit vars
    x = 0
    y = yrad
    xChg = yrad * yrad
    yChg = xrad * xrad * (1 - (yrad *2))
    err = 0
    xStopping = 0
    yStopping = xrSqTwo * yrad

    while (xStopping <= yStopping)
        # Draw 4 quadrant points at once
        if filled then
            #filled ellipse, dig a line across.
            xi = 2 * x + xeven # loop variable
            while xi >= 0
                digAt(xc - x + xi, yc + y + yeven, z0, digMode)
                digAt(xc - x + xi, yc - y, z0, digMode)
                xi -= 1
            end
        else
            #hollow ellipse
            digAt(xc + x + xeven, yc + y + yeven, z0, digMode)
            digAt(xc - x, yc + y + yeven, z0, digMode)
            digAt(xc - x, yc - y, z0, digMode)
            digAt(xc + x + xeven, yc - y, z0, digMode)
        end

        x+= 1
        xStopping += yrSqTwo
        err += xChg
        xChg += yrSqTwo
        if ((yChg + (err * 2)) > 0) then
            y-= 1
            yStopping -= xrSqTwo
            err += yChg
            yChg += xrSqTwo
        end
    end
end

def digKeupoStair(x, y, z, depth)
    #Dig an X of updown stairs (corners and center of a 3x3) centered on cursor, down a number of zlevels.
    iz = z
    digAt(x, y, iz, 'j')
    digAt(x - 1, y + 1, iz, 'j')
    digAt(x - 1, y - 1, iz, 'j')
    digAt(x + 1, y + 1, iz, 'j')
    digAt(x + 1, y - 1, iz, 'j')
    while iz >= z - (depth - 1) do
        digAt(x, y, iz, 'i')
        digAt(x - 1, y + 1, iz, 'i')
        digAt(x - 1, y - 1, iz, 'i')
        digAt(x + 1, y + 1, iz, 'i')
        digAt(x + 1, y - 1, iz, 'i')
        iz -= 1
    end
end

def drawPolygon(x0, y0, z0, x1, y1, z1, n = 3, apothem=false, digMode = 'd')
    #Draw a polygon centered on origin with cursor at (apothem==T: midpoint of a side, ==F: vertex)
    # if you dig a 2-gon (aka a line) it always passes through the origin so it's still convienient / useful. In apothem==T this makes the origin the midpoint of the drawn line.

    xOffset = x1 - x0
    yOffset = y1 - y0

    radius = Math.sqrt(xOffset ** 2 + yOffset ** 2)

    angle=Math::atan2(yOffset/radius,xOffset/radius)
    angleIncrement = (Math::PI*2)/n;

    lastX = x1
    lastY = y1

    if apothem==true then #cursor is at middle of a segment instead of vertex
        angle+=angleIncrement/2
        radius=radius/Math.cos(Math::PI/n)
    end

    for i in 0..n
        thisX = (x0 + (Math.cos(angle)*radius)).round
        thisY = (y0 + (Math.sin(angle)*radius)).round
        if (i > 0) then
            drawLine(lastX, lastY, z0, thisX, thisY, z0, digMode)
        end
        angle += angleIncrement
        lastX = thisX
        lastY = thisY
    end
end

def drawStar(x0, y0, z0, x1, y1, z1, n = 5, skip = 2, digMode = 'd')
    #Draw a star centered at origin, with cursor at a vertex.
    xOffset = x1 - x0
    yOffset = y1 - y0

    radius = Math.sqrt(xOffset ** 2 + yOffset ** 2)

    angle=Math::atan2(yOffset/radius,xOffset/radius)
    angleIncrement = (Math::PI*2)/n;

    lastX = x1
    lastY = y1

    for i in 0..n
        thisX = (x0 + (Math.cos(angle)*radius)).round
        thisY = (y0 + (Math.sin(angle)*radius)).round
        thatX = (x0 + (Math.cos(angle+(angleIncrement*skip))*radius)).round
        thatY = (y0 + (Math.sin(angle+(angleIncrement*skip))*radius)).round
        if (i > 0) then
            drawLine(thatX, thatY, z0, thisX, thisY, z0, digMode)
        end
        angle += angleIncrement
    end
end

def drawSpiral(x0, y0, z0, x1, y1, z1, coils, chord = 10, digMode = 'd')
    # Draw a spiral centered at the origin, to a radius of the cursor. It makes <coils> turns, and if <chord> is >1, is made of points rather than a line.remaining
    # Source: https://stackoverflow.com/questions/13894715/draw-equidistant-points-on-a-spiral

    # ('0'=no rotation, '1'=360 degrees, '180/360'=180 degrees)
    rotation = 0

    # value of theta corresponding to end of last coil
    thetaMax = coils * 2 * Math::PI

    xOffset = x1 - x0
    yOffset = y1 - y0

    radius = Math.sqrt(xOffset ** 2 + yOffset ** 2)
    if (radius > 0.0) then
        # How far to step away from center for each side.
        awayStep = radius / thetaMax

        digAt(x0, y0, z0, digMode)

        # For every side, step around and away from center.
        # start at the angle corresponding to a distance of chord
        # away from centre.
        theta = chord / awayStep

        while (theta.abs <= thetaMax.abs)
            # How far away from center
            away = awayStep * theta

            # How far around the center.
            around = theta + rotation

            # Convert 'around' and 'away' to X and Y.
            x = x0 + (Math.cos(around) * away).round
            y = y0 + (Math.sin(around) * away).round

            digAt(x, y, z0, digMode)

            # to a first approximation, the points are on a circle
            # so the angle between them is chord/radius
            theta += chord / away
        end
    end
end

def floodfill(x,y,z,targetDig, digMode, maxCounter= 10000)
    #Flood fills out from the cursor until different designation reached (eg if on 'd' fill only 'd', if on empty, fill only empty). Rooks move adjacency only.

    #targetDig: what designation type can we overwrite?
    #digMode: what designation are we placing?
    #maxCounter: a limit to help with performance.
    
    counter = maxCounter #max flood fill.
    t=df.map_tile_at(x,y,z)
    
    if not t then
        #ignore impossible tiles (eg air.)
        stdout("Tile does not exist")
        throw :script_finished
        return
    end
    
    digNum = digMode2enum(digMode) #Stash this, we'll use it many times.
    
    if t.designation.dig == digNum then
        #don't dig tiles that are already dug
        stdout("Tile is already dug")
        throw :script_finished
        return
    end
    
    #scan for next tile to dig.
    xStack = [x]
    yStack = [y]
    
    loop do
        x= xw = xe = xStack.pop()
        y = yStack.pop() #always push/pop x&y together.
        
        #search W for bounds
        loop do
            xi = xw - 1 #move xw cursor west until it hits a match
            t=df.map_tile_at(xi,y,z)
            
            if !t || xi == 0  || t.designation.dig != targetDig || !isDigPermitted(digMode,t.shape_basic) then 
                break
            end
            xw = xi
        end
        
        #search E for bounds
        loop do
            xi = xe + 1 #move xe cursor east until it hits a match
            t=df.map_tile_at(xi,y,z)
            
            if !t || xi == 0  || t.designation.dig != targetDig || !isDigPermitted(digMode,t.shape_basic) then 
                break
            end
            xe = xi
        end
        
       #scan W..E filling, and checking N/S
        for xi in xw..xe do
            digAt(xi, y, z, digMode)
            
            counter = counter -1
            if counter <=0 then 
                stdout("  Max coverage of #{maxCounter} tiles reached. Use multiple floods, or add a number for max coverage as 'digshape flood [max coverage] [dig type]'.")
                stdout("  Automatically cancelling flood")
                undo()
                return 
            end
            
            #check N/S
            t = df.map_tile_at(xi,y+1,z)
            if t && t.designation.dig == targetDig && isDigPermitted(digMode,t.shape_basic) then
                xStack.push(xi)
                yStack.push(y+1)
                end
            t = df.map_tile_at(xi,y-1,z)
            if t && t.designation.dig == targetDig && isDigPermitted(digMode,t.shape_basic) then 
                xStack.push(xi)
                yStack.push(y-1)
                end
            end
        
        if xStack.length <=0 then
            break
        end
    end
end






=begin
========================  SCRIPT CONTROL
script execution start
=end

if not $script_args[0] or $script_args[0]=="help" or $script_args[0]=="?" then

    stdout "  To set origin: digshape origin"
    stdout "  To draw line after origin is set: digshape line"
    stdout "  To draw ellipse after origin is set (as bounding box): digshape ellipse <fill:filled|hollow>"
    stdout "..To draw an ellipse after origin is set (by major and minor axis): digshape major (must be horizontal or vertical), then digshape ellipse3p"
    stdout "  To draw a 3 point bezier curve after origin and major are set: digshape bez <sharpness=1.5>"
    stdout "..To draw a circle after origin is set, select any point as a diameter: digshape circle2p <fill:filled|hollow>"
    stdout "  To draw a polygon after origin is set (as center) with the cursor as a vertex: digshape polygon <# sides>"
    stdout "  To draw a polygon after origin is set (as center) with the cursor as a midpoint of a segment(apothem): digshape polygon <# sides> apothem"
    stdout "  To draw a star after origin is set (as center) with the cursor as a vertex : digshape star <# points> <skip=2>"
	stdout "To draw an Archimedean spiral (coils - number of coils, chord - distance between points):
            digshape spiral <coils> <chord>"
    stdout "  To draw downstair: digshape downstair depth"
    stdout "  "
    stdout "   To flood fill with a designation, overwriting ONLY the designation under the cursor (warning: slow on areas bigger than 10k tiles..): digshape flood [maxArea=10000]"
    stdout "  To undo the previous command (restoring designation): digshape undo"
    stdout "  To move all markers to the current z level (without displaying them): digshape resetz"
    stdout "  All commands accept a one letter digging designation [dujihrx] at the end, or will default to 'd'"
    throw :script_finished
end

command = $script_args[0]
$script_args.delete_at(0)

if df.cursor.x == -30000 then
    userSucks("Cursor must be on map")
end

if not (command == 'undo' or command=='u') and not $isPreviewOnly then
    clearDigBuffer() #clear the dig buffer so we can undo the following command. Or initialize it's first run
end

def requireOriginZLevel(msg: "Origin and target must be on the same z-level (use command 'digshape resetz' or 'digshape setz [Z-level, default=Cursor Z]' to fix)")
    #Ensure cursor is on same z as origin (TODO: and control points).
    if df.cursor.z != $origin.z then
        userSucks(msg)
    end
    writeLuaPos("origin",$origin) # visualize them for the user
end

def requireMajor(msg: "Set a point for the end of the major axis with the cursor and 'digshape major'")
    #Ensure control point: 'major' has been set and is valid.
    if $major == nil then
        userSucks(msg)
    end
    requireOriginZLevel()
    writeLuaPos("origin", $origin)  # visualize them for the user
    writeLuaPos("major", $major)    # visualize them for the user
end

def getDigModeArgument(args)
    #get next[LAST] script argument IFF it is a digmode designation, or set default if not present.
    argument = args[0] 
    digMode = getDigMode(argument)
    #if not ['d', 'u', 'j', 'i', 'h', 'r', 'x'].include? digMode then
    #   digMode='d'
    #end
    args.delete_at(0)

    return digMode
end

def getFilledArgument(args, default: false)
    #get next script argument IFF it is fill.
    # this doesn't *expect* and argument and so only consumes an argument when something matches
    argument = args[0]
    case argument
        when 'filled', 'f', 'true', 'yes', 'y'; filled = true
        when 'hollow', 'h', 'false', 'no', 'n'; filled = false
        else
            return default # doesn't consume if nothing matches
    end
    args.delete_at(0);
    return filled
end

def getFloatArgument(args, default: nil, type: "(unnamed number)", positive: true)
    #get next script argument, which must be a float.
    num = args[0]
    result = nil
    defaultMessage = ""

    if default != nil then
        defaultMessage = "Use `-' for the default value (#{default})"
    end

    if not num then
        userSucks("Must supply #{type} parameter (number).#{defaultMessage}")
    end
    args.delete_at(0)
    
    case num
        when 'default','-';
            userSucks("No default value for #{type} parameter!") if default == nil
            result = default 
        else
            result = Float(num) rescue userSucks("Malformed number for "+type+" parameter, got `"+num+"'.#{defaultMessage}")
    end

    if positive && result<0 then 
        userSucks("Expected positive number for #{type} parameter, got `#{num}'.#{defaultMessage}")
    end
    
    return result
end

def getIntegerArgument(args, default: nil, type: "(unnamed integer)", positive: true)
    #get next script argument, which must be an integer.
    num = args[0]
    result = nil
    defaultMessage = ""

    if default != nil then
        defaultMessage = "Use `-' for the default value (#{default})"
    end

    if not num then
        userSucks("Must supply #{type} parameter (integer).#{defaultMessage}")
    end
    args.delete_at(0)
    
    case num
        when 'default','-';
            userSucks("No default value for #{type} parameter!") if default == nil
            result = default 
        else
            result = Integer(num) rescue userSucks("Malformed integer for "+type+" parameter, got `"+num+"'.#{defaultMessage}")
    end

    if positive && result<0 then 
        userSucks("Expected positive integer for #{type} parameter, got `#{num}'.#{defaultMessage}")
    end
    
    return result
end

def makeDefaultPosMap(oldPos)
    return {
        '~' => cursorAsDigPos(), # cursor positon
        '-' => oldPos.clone() # old value of this (i.e. leave it unchanged)
    }
end

def getPosComponentArgument(args, defaultMap, symbol)
    if defaultMap[args[0]] then # it is either ~ or -
        value = defaultMap[args[0]][symbol]
        args.delete_at(0)
        return value
    else # it is an integer
        return getIntegerArgument(args, type: "#{symbol.to_s} coordinate", positive: true)
    end
end

def getPositionArgument(args, oldPos, default: nil) # X Y Z, ~ ~ ~, - - -, or any mix # returns nil if no default!
    if args[0] && args[1] && args[2] then
        defaultMap = makeDefaultPosMap(oldPos)
        return DigPos.new(getPosComponentArgument(args, defaultMap, :x), 
                          getPosComponentArgument(args, defaultMap, :y),
                          getPosComponentArgument(args, defaultMap, :z))
    else
        return default
    end
end

def noMoreArguments(args)
    if args[0] then
        userSucks("Did not expect more arguments #{args}")
    end
end





=begin
========================  DIGSHAPE COMMANDS
=end


#def registerCommand(name, aliases, usage)
#    return "TODO:"
#end


case command
    when 'origin', 'o', 'set'
        # $usage = createUsage(name: 'origin', aliases: ['o', 'set']) # TODO ADD USAGES TO EACH COMMANDS, make scriptError/userSucks print them out
        # Even better, to refator all these commands with associated data into classes / anonoymous functions so we can eventually do digshape help <command name>
        newOrigin = getPositionArgument($script_args, $origin, default: cursorAsDigPos())
        noMoreArguments($script_args)

        setOrigin(newOrigin.x, newOrigin.y, newOrigin.z) # need to refactor setOrigin

        writeLuaPos("origin", $origin)

    when 'major', 'm' #used to mark the end point of the major diameter
        newMajor = getPositionArgument($script_args, $major, default: cursorAsDigPos())
        noMoreArguments($script_args)

        requireOriginZLevel()

        setMajor(newMajor.x, newMajor.y, newMajor.z) # need to refactor setMajor
        
        writeLuaPos("major", $major)

        stdout("Now move the cursor to the minor axis radius (extent) and call ellipse3p")

    when 'resetz', 'setz'
        z = df.cursor.z # default

        if args[0] then
            z = getPosComponentArgument(args, makeDefaultPosMap(origin), :z) # only really need the z-component from origin for default
        end
        noMoreArguments($script_args)

        setOrigin($origin.x, $origin.y, z)
        if $major then
            setMajor($major.x, $major.y, z)
        end

    when 'ls', 'status'
        stdout("origin: #{$origin != nil ? $origin.to_s : '<nil>'}")
        stdout("major : #{$major != nil ? $major.to_s : '<nil>'}")
        stdout("cursor: #{cursorAsDigPos().to_s}")
        
    when 'line', 'l'
        digMode = getDigModeArgument($script_args)
        noMoreArguments($script_args)

        requireOriginZLevel()

        drawLine($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.z, digMode)

    when 'ellipse', 'e' #digshape ellipse [filled] [digmode]
        filled = getFilledArgument($scripts_args)
        digMode = getDigModeArgument($script_args)
        noMoreArguments($script_args)

        requireOriginZLevel()

        drawEllipse($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.z, x2=nil, y2=nil, z2=nil, filled=filled, digMode=digMode, mode='bbox') # fixme: default arguments should be colon not equals

    when 'circle2p', 'circle', 'c' #digshape circle2p [filled] [digmode]
        filled = getFilledArgument($script_args)
        digMode = getDigModeArgument($script_args) #check argument 1 for dig instructions
        noMoreArguments($script_args)

        requireOriginZLevel()

        drawEllipse($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.z, x2=nil, y2=nil, z2=nil, filled=filled, digMode=digMode, mode='diameter') # fixme: default arguments should be colon not equals

    when 'ellipse3p', 'e3p' #digshape ellipse3p [filled] [digmode]
        filled = getFilledArgument($script_args)
        digMode = getDigModeArgument($script_args)
        noMoreArguments($script_args)

        requireOriginZLevel(msg:"All control points must be on the same z level")
        requireMajor()
        
        if filled then
            stdout("Filled not yet supported for 3p ellipses.")
            filled = false
        end

        drawEllipse($origin.x, $origin.y, $origin.z, $major.x, $major.y, $major.z, df.cursor.x, df.cursor.y, df.cursor.z, filled=filled, digMode=digMode, mode='axis') # fixme: default arguments should be colon not equals

    when 'bezier', 'bez', 'b' #digshape bezier [weight] digmode]
        #use origin and major as endpoints, cursor as curve shaper
        weight = getFloatArgument($script_args, default: 1.5, type: "bezier weight")
        digMode = getDigModeArgument($script_args) #check argument 1 for dig instructions
        noMoreArguments($script_args)
        
        requireOriginZLevel(msg:"All control points must be on the same z level")
        requireMajor()
        
        plotQuadRationalBezier($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.z, $major.x, $major.y, $major.z, weight, digMode)

    when 'polygon', 'p' #digshape polygon [sides] [apothem/radius] [digMode] # apothem is default
        sides = getIntegerArgument($script_args, type: "polygon n-sides")
        
        apothem = false # custom argument parse
        case $script_args[0]
            when 'apothem', 'a', 't', 'true', 'y', 'yes'; apothem=true; $script_args.delete_at(0)
            when 'radius', 'r', 'f', 'false', 'n', 'no'; apothem=false; $script_args.delete_at(0)
        end

        digMode = getDigModeArgument($script_args)
        noMoreArguments($script_args)

        requireOriginZLevel()

        drawPolygon($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.z, sides, apothem, digMode)

    when 'star', 's' #digshape star N [skip=2] [digMode]
        n = getIntegerArgument($script_args, type: "star n-sides")

        skip = getIntegerArgument($script_args, default: 2, type: "skip")
        digMode = getDigModeArgument($script_args)

        noMoreArguments($script_args)

        requireOriginZLevel()

        drawStar($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.z, n, skip, digMode)

	when 'spiral'
        coils=getIntegerArgument($script_args, default: 2, type: "number of coils")
        chord=getIntegerArgument($script_args, default: 1, type: "distance between points")
        digMode = getDigModeArgument($script_args)
        noMoreArguments($script_args)

        drawSpiral($origin.x, $origin.y, $origin.z, df.cursor.x, df.cursor.y, df.cursor.x, coils, chord, digMode)

    when 'keupo', 'stairs', 'downstairs', 'downstair' #digshape keupo depth
        depth = getIntegerArgument($script_args, type: "depth")

        noMoreArguments($script_args)

        if depth <= 0 then
            userSucks("Depth must be an integer greater than zero")
        end
        
        digKeupoStair(df.cursor.x, df.cursor.y, df.cursor.z, depth)

    when 'flood', 'f'
        maxArea = getIntegerArgument($script_args, default: 10000, type: "maximum flood area")
        digMode = getDigModeArgument($script_args)

        noMoreArguments($script_args)
        
        tile = df.map_tile_at(df.cursor.x, df.cursor.y, df.cursor.z)
        targetDig = tile.designation.dig #we will only fill the designation type under the cursor.
        
        if targetDig != :No then
            if targetDig == digMode2enum(digMode) then
                userSucks("Floodfill must be centered on an undesignated/matching tile.")
            end
        end

        floodfill(df.cursor.x, df.cursor.y, df.cursor.z, targetDig, digMode, maxArea)

    when 'undo', 'u'
        undo()
        
    else
        userSucks("Invalid command")
end