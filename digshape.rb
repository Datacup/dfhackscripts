# dig shapes
=begin

digshape
=======

Commands that do not require a set origin:

    To dig a 3x3 sparse up-down stairway:
        digshape downstair <depth>
    
    To undo the previous command (restoring designation): digshape undo

Commands that require an origin to be set:

    To set the origin for drawing:
        digshape origin

    To draw to the target point:
        digshape line
    
    To draw an ellipse using the origin and target as a bounding box:
        digshape ellipse (filled? [default: false])
    
    To draw an ellipse using the origin and target as a major axis, and the cursor as the length of the semiminor axis:
        digshape major (to set the major axis endpoint)
        digshape ellipse3p
    
    To draw a circle using an arbitrary diameter:
        digshape circle2p
    
    To draw a 3 pt bezier curve, with an arbitrary float for weighting the sharpness:
        digshape major (to set the end point of the curve)
        digshape bez [sharpness=1.5]
      
    To draw a polygon using the origin as the center and the cursor as the radius|apothem (radius)
        digshape polygon <sides> [radius|apothem] [digMode]
    
    To flood fill with a designation, overwriting ONLY the designation under the cursor:
        digshape flood
    
    To move all of the markers to the current z level:
        digshape resetz

    To draw an Archimedean spiral (coils - number of coils, chord - distance between points):
        digshape spiral <coils> <chord>

    To draw an Archimedean spiral (coils - number of coils, chord - distance between points):
        digshape spiral <coils> <chord>

    All commands accept a digging designation mode as a single character argument [dujihrx], otherwise will default to 'd'

TODO: mark origin should not change the digging designation, ellipse cleanup should restore not clear it.

=end

def markOrigin(ox, oy, oz)
    t = df.map_tile_at(ox, oy, oz)
    if t then
        s = t.shape_basic
        #TODO: preseve designation:
        #$originTile = t.designation # a global to store the original origin state
        #puts "origin: #{$originTile}"
        t.dig(:Default) if s == :Wall
    end
end


def unDig()
    #Exicute one level of undo.
    #z level is presumed to be the current.
    i=$digBufferX.length
    while i >= 0 do
        x=$digBufferX.pop
        y=$digBufferY.pop
        d=$digBufferD.pop
        
        digAt(x,y,df.cursor.z, enum2dig(d), buffer=false)
        i = i-1
        end
    #clear buffer for next dig.
    clearDigBuffer()
end


def clearDigBuffer()
    #clear buffer for next dig, or initialize it's existance on first run.
    $digBufferX=[]
    $digBufferY=[]
    $digBufferD=[]
end


def digAt(x, y, z, digMode = 'd', buffer=true)
    t = df.map_tile_at(x, y, z)
    
    #store the current tile's designation in a undo buffer
    if buffer then
        $digBufferX.push(x)
        $digBufferY.push(y)
        $digBufferD.push(t.designation.dig)
    end
    

    # check if the tile returned is valid, ignore if its not (out of bounds, air, etc)
    if t then
        s = t.shape_basic

        case digMode #from https://github.com/DFHack/scripts/blob/master/digfort.rb
            when 'd'; t.dig(:Default) if s == :Wall
            when 'u'; t.dig(:UpStair) if s == :Wall
            when 'j'; t.dig(:DownStair) if s == :Wall or s == :Floor
            when 'i'; t.dig(:UpDownStair) if s == :Wall
            when 'h'; t.dig(:Channel) if s == :Wall or s == :Floor
            when 'r'; t.dig(:Ramp) if s == :Wall
            when 'x'; t.dig(:No)
            else
                puts "  Error: Unknown digtype"
                throw :script_finished
        end
    end
end

# https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
def drawLineLow(x0, y0, z0, x1, y1, z1, digMode = 'd')
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
    #/* plot a limited rational Bezier segment, squared weight */
    #http://members.chello.at/easyfilter/bresenham.pdf listing 12
    #p0:origin, p1:weight, p2:termination
    #w is the weighting. "For w =1 the curve is a parabola, for w < 1 the curve is an ellipse, for w = 0 the curve is a straight line and for w>1 the curve is a hyperbola. The weights are normally assumed to be all positive."
    
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
    #http://members.chello.at/easyfilter/bresenham.pdf listing 11
    ## plot any quadratic rational Bezier curve */

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
    ## plot ellipse rotated by angle (radian) */
    #taken from: http://members.chello.at/easyfilter/bresenham.pdf listing 13. Explicitly released without copyright
    #Note: most of this function deals with the ellipse at the origin. Translation to coordinates is at final call.
    
    #x,y is the coodinates of the center
    #a is __SEMI__major length
    #b is __SEMI__minor length
    #angle (radians), prob measured CCW from east
    
    #A far more readable paper on plotting rotated ellipses (no pseudocode): http://www.crbond.com/papers/ell_alg.pdf
    #Another paper on rasterizing 2d primitives: https://cs.brown.edu/research/pubs/theses/masters/1989/dasilva.pdf

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
        puts "zd=0 degenerate case"
        drawEllipse(x0,y0,z0, x1,y1,z0)
        return
    end
    
    ## squared weight of P1 */
    if (w != 0.0) then
        w = (w - zd) / (w + w)
        end
    
    if not(w <= 1.0 && w >= 0.0) then  #/* limit angle to |zd|<=xd*yd */
        puts "  Error: Limit angle to |zd|<=xd*yd"
        throw :script_finished
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
    # A Fast Bresenham Type Algorithm For Drawing Ellipses http://homepage.smc.edu/kennedy_john/belipse.pdf (https://www.dropbox.com/s/3q89g566u115g3q/belipse.pdf?dl=0)
    # also adapted from https://github.com/teichgraf/WriteableBitmapEx/blob/master/Source/WriteableBitmapEx/WriteableBitmapShapeExtensions.cs used under the MIT license
    
    #p0 [xyz]: origin of major axis; OR a corner of bbox
    #p1 [xyz]: termination of major axis; OR the other corner of the bbox
    #p2 [xyz]: the extent (not a point nessisarily on the minor axis..) of the minor _radius_; aka, a point on the bounding box long side that will be used to determine the length of the short side.

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

def getDigMode(digMode = 'd')
    if ['d', 'u', 'j', 'i', 'h', 'r', 'x'].include? digMode then
        return digMode
    end
    return 'd'
end

def drawPolygon(x0, y0, z0, x1, y1, z1, n = 3, apothem=false, digMode = 'd')
    # if you dig a 2-gon (aka a line) it always passes through the origin so it's still convienient / useful

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

def dig2enum(digMode)
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
            puts "  Error: Unknown digtype"
            throw :script_finished
    end
end


def enum2dig(digEnum)
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
            puts "  Error: Unknown digEnum"
            throw :script_finished
    end
end

def digPermitted(digMode, tileShape_basic)
    #can we dig on this tile?
    
    if not tileShape_basic then return false end
    
    case digMode
        when 'd'; if tileShape_basic == :Wall then return true else return false end
        when 'u'; if tileShape_basic == :Wall then return true else return false end
        when 'j'; if tileShape_basic == :Wall || tileShape_basic == :Floor  then return true else return false end
        when 'i'; if tileShape_basic == :Wall then return true else return false end
        when 'h'; if tileShape_basic == :Wall || tileShape_basic == :Floor  then return true else return false end
        when 'r'; if tileShape_basic == :Wall then return true else return false end
        when 'x'; return true
        else
            puts "  Error: Unknown digtype"
            throw :script_finished
        end
    end

def floodfill(x,y,z,targetDig, digMode, maxCounter= 10000)
    #targetDig: what designation type can we overwrite?
    #digMode: what designation are we placing?
    #maxCounter: a limit to help with performance.
    
    counter = maxCounter #max flood fill.
    t=df.map_tile_at(x,y,z)
    
    if not t then
        #ignore impossible tiles (eg air.)
        throw :script_finished
        return
    end
    
    digNum = dig2enum(digMode) #Stash this, we'll use it many times.
    
    if t.designation.dig == digNum then
        #don't dig tiles that are already dug
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
            
            if !t || xi == 0  || t.designation.dig != targetDig || !digPermitted(digMode,t.shape_basic) then 
                break
            end
            xw = xi
        end
        
        #search E for bounds
        loop do
            xi = xe + 1 #move xe cursor east until it hits a match
            t=df.map_tile_at(xi,y,z)
            
            if !t || xi == 0  || t.designation.dig != targetDig || !digPermitted(digMode,t.shape_basic) then 
                break
            end
            xe = xi
        end
        
       #scan W..E filling, and checking N/S
        for xi in xw..xe do
            digAt(xi, y, z, digMode)
            
            counter = counter -1
            if counter <=0 then 
                puts "  Max coverage of #{maxCounter} tiles reached. Use multiple floods, or add a number for max coverage as 'digshape flood [max coverage] [dig type]'."
                return 
            end
            
            #check N/S
            t = df.map_tile_at(xi,y+1,z)
            if t && t.designation.dig == targetDig && digPermitted(digMode,t.shape_basic) then
                xStack.push(xi)
                yStack.push(y+1)
                end
            t = df.map_tile_at(xi,y-1,z)
            if t && t.designation.dig == targetDig && digPermitted(digMode,t.shape_basic) then 
                xStack.push(xi)
                yStack.push(y-1)
                end
            end
        
        if xStack.length <=0 then
            break
        end
    end
end


# based on an algorithm in this stackoverflow question
# https://stackoverflow.com/questions/13894715/draw-equidistant-points-on-a-spiral
def drawSpiral(x0, y0, z0, x1, y1, z1, coils, chord = 10, digMode = 'd')
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


# script execution start

if not $script_args[0] or $script_args[0]=="help" or $script_args[0]=="?" then
    puts "  To draw downstair: digshape downstair depth"
    puts "  To set origin: digshape origin"
    puts "  To draw line after origin is set: digshape line"
    puts "  To draw ellipse after origin is set (as bounding box): digshape ellipse <fill:filled|hollow>"
    puts "..To draw an ellipse after origin is set (by major and minor axis): digshape major (must be horizontal or vertical), then digshape ellipse3p"
    puts "  To draw a 3 point bezier curve after origin and major are set: digshape bez <sharpness=1.5>"
    puts "..To draw a circle after origin is set, select any point as a diameter: digshape circle2p <fill:filled|hollow>"
    puts "  To draw a polygon after origin is set (as center) with the cursor as a vertex: digshape polygon <# sides>"
    puts "  To draw a polygon after origin is set (as center) with the cursor as a midpoint of a segment(apothem): digshape polygon <# sides> apothem"
    puts "  To draw a star after origin is set (as center) with the cursor as a vertex : digshape star <# points> <skip=2>"
    puts "   To flood fill with a designation, overwriting ONLY the designation under the cursor (warning: slow on areas bigger than 10k tiles..): digshape flood [maxArea=10000]"
    puts "  To undo the previous command (restoring designation): digshape undo"
    puts "  To move all markers to the current z level (without displaying them): digshape resetz"
    puts "  All commands accept a one letter digging designation [dujihrx] at the end, or will default to 'd'"
    throw :script_finished
end

command = $script_args[0]
argument1 = $script_args[1]
argument2 = $script_args[2]
argument3 = $script_args[3]

if df.cursor.x == -30000 then
    puts "  Error: cursor must be on map"
    throw :script_finished
end

if command=="o" or command=="set" then #alias
    command="origin"
elsif command=="keupo" or command=="stairs" or command=="downstairs" then
    command="downstair"
end

if command != 'undo' then
    clearDigBuffer() #clear the dig buffer so we can undo the following command. Or initialize it's first run
end

case command
    when 'origin'
        $originx = df.cursor.x
        $originy = df.cursor.y
        $originz = df.cursor.z

        markOrigin($originx, $originy, $originz)
    when 'resetz'
        $originz = $majorz = df.cursor.z
    when 'line'
        dig = getDigMode(argument1)

        if df.cursor.z == $originz then
            drawLine($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, dig)
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'ellipse' #digshape ellipse [filled] [digmode]
        filled = false
        case argument1
            when 'filled'; filled = true
            when 'hollow'; filled = false
            when 'true'; filled = true
            when 'false'; filled = false
            when 't'; filled = true
            when 'f'; filled = false
            when 'y'; filled = true
            when 'n'; filled = false
        end

        dig = getDigMode(argument1) #check argument 1 for dig instructions
        if argument2 then # if argument 2 is present, look at that for dig instructions
            dig = getDigMode(argument2)
        end

        if df.cursor.z == $originz then
            drawEllipse($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, x2=nil, y2=nil, z2=nil, filled=filled, digMode=dig, mode = 'bbox')

            # remove origin designation
            digAt($originx, $originy, $originz, 'x')
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'circle2p' #digshape circle2p [filled] [digmode]
        filled = false
        case argument1
            when 'filled'; filled = true
            when 'hollow'; filled = false
            when 'true'; filled = true
            when 'false'; filled = false
            when 't'; filled = true
            when 'f'; filled = false
            when 'y'; filled = true
            when 'n'; filled = false
        end
        
        dig = getDigMode(argument1) #check argument 1 for dig instructions
        if argument2 then # if argument 2 is present, look at that for dig instructions
            dig = getDigMode(argument2)
        end

        if df.cursor.z == $originz then
            drawEllipse($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, x2=nil, y2=nil, z2=nil, filled=filled, digMode = dig, mode = 'diameter')
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'major' #digshape major
        #used to mark the end point of the major diameter
        #$major = df.cursor
        $majorx = df.cursor.x
        $majory = df.cursor.y
        $majorz = df.cursor.z
        if df.cursor.z == $originz then
            markOrigin($majorx, $majory, $majorz)
            puts "  Now move the cursor to the minor axis radius (extent) and call ellipse3p"
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'ellipse3p' #digshape ellipse3p [filled] [digmode]
        if df.cursor.z == $originz then
            if $majorx == nil then
                puts "  Error: Set a point for the end of the major axis with the cursor and 'digshape major'"
                throw :script_finished
                end
            
            filled = false
            case argument1
                when 'filled'; filled = true
                when 'hollow'; filled = false
                when 'true'; filled = true
                when 'false'; filled = false
                when 't'; filled = true
                when 'f'; filled = false
                when 'y'; filled = true
                when 'n'; filled = false
            end
            
            if filled then
                puts "  Filled not yet supported for 3p ellipses."
                filled = false
                end

            dig = getDigMode(argument1) #check argument 1 for dig instructions
            if argument2 then # if argument 2 is present, look at that for dig instructions
                dig = getDigMode(argument2)
            end

            drawEllipse($originx, $originy, $originz, $majorx, $majory, $majorz, df.cursor.x, df.cursor.y, df.cursor.z, filled = filled, digMode = dig, mode = 'axis')
        else
            puts "  Error: all control points must be on the same z level"
            throw :script_finished
        end
    when 'bez' #digshape bez
        #use origin and major as endpoints, cursor as curve shaper
        if df.cursor.z == $originz then
            if $majorx == nil then
                    puts "  Error: Set an endpoint for the curve with the cursor and 'digshape major'"
                    throw :script_finished
                    end
            
            weight = argument1.to_f
            if weight = 0 then 
                weight = 1.5 
            end
            
            dig = getDigMode(argument1) #check argument 1 for dig instructions
            if argument2 then # if argument 2 is present, look at that for dig instructions
                dig = getDigMode(argument2)
            end
            
            plotQuadRationalBezier($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, $majorx, $majory, $majorz, weight, dig)
        else
            puts "  Error: all control points must be on the same z level"
            throw :script_finished
        end
    when 'polygon'
        if not argument1 then
            puts "  Must supply a polygon n-sides parameter"
            throw :script_finished
        else
            n = argument1.to_i
            dig = getDigMode(argument2)
            if argument3 then
                dig = getDigMode(argument3)
            end
            apothem=false;
            case argument2
                when 'apothem'; apothem=true
                when 'radius'; apothem=false
                when 'a'; apothem=true
                when 'r'; apothem=false
                when 't'; apothem=true
                when 'f'; apothem=false
                when 'y'; apothem=true
                when 'n'; apothem=false
            end
            if df.cursor.z == $originz then
                drawPolygon($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, n, apothem, dig)
            else
                puts "  Error: origin and target must be on the same z level"
                throw :script_finished
            end
        end
    when 'star' # star N [SKIP=2] [DIGMODE]
        if not argument1 then
            puts "  Must supply a star n-sides parameter"
            throw :script_finished
        else
            dig = getDigMode(argument2)
            if argument3 then
                dig = getDigMode(argument3)
            end
            n = argument1.to_i
            skip = Integer(argument2) rescue 2

            if df.cursor.z == $originz then
                drawStar($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, n, skip, dig)
            else
                puts "  Error: origin and target must be on the same z level"
                throw :script_finished
            end
        end
    when 'downstair'
        if not argument1 then
            puts "  Must supply a depth parameter"
            throw :script_finished
        else
            depth = argument1.to_i
            if depth <= 0 then
                puts "  Depth must be an integer greater than zero"
                throw :script_finished
            else
                digKeupoStair(df.cursor.x, df.cursor.y, df.cursor.z, depth)
            end
        end
    when 'flood'
        maxArea = argument1.to_i
        if maxArea == 0 then maxArea = 10000 end
        
        dig = getDigMode(argument1) #check argument 1 for dig instructions
        if argument2 then # if argument 2 is present, look at that for dig instructions
            dig = getDigMode(argument2)
        end
        
        t=df.map_tile_at(df.cursor.x, df.cursor.y, df.cursor.z)
        targetDig = t.designation.dig #we will only fill the designation type under the cursor.
        
        if not t.designation.dig==:No then
            if dig2enum(dig) == t.designation.dig then
            puts "  Error: floodfill must be centered on an undesignated/matching tile."
            throw :script_finished
            end
        end

        floodfill(df.cursor.x, df.cursor.y, df.cursor.z, targetDig, dig, maxArea)
        throw :script_finished
    when 'undo'
        unDig()
    when 'spiral'
        if not argument1 then
            puts "  Must supply a coils parameter"
            throw :script_finished
        else
            coils = argument1.to_i
            chord = 2
            if argument2 then
                chord = argument2.to_i
            end

            dig = getDigMode(argument3)

            drawSpiral($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.x, coils, chord, dig)
        end
    else
        puts "  Error: Invalid command"
        throw :script_finished
end
