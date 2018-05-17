# dig shapes
=begin

digshape
=======

Commands that do not require a set origin:

    To dig a 3x3 sparse up-down stairway:
        digshape downstair <depth>

Commands that require an origin to be set:

    To set the origin for drawing:
        digshape origin

    To draw to the target point:
        digshape line
    
    To draw an ellipse using the origin and target as a bounding box:
        digshape ellipse (filled? [default: false])
      
    To draw a polygon using the origin as the center and the cursor as the radius|apothem (radius)
        digshape polygon <sides> [radius|apothem] [digMode]

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

def digAt(x, y, z, digMode = 'd')
    t = df.map_tile_at(x, y, z)

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

def drawEllipse(x0, y0, z0, x1, y1, z1, x2=nil, y2=nil, z2=nil, filled = false, digMode = 'd', mode = 'bbox')
    # A Fast Bresenham Type Algorithm For Drawing Ellipses http://homepage.smc.edu/kennedy_john/belipse.pdf (https://www.dropbox.com/s/3q89g566u115g3q/belipse.pdf?dl=0)
    # also adapted from https://github.com/teichgraf/WriteableBitmapEx/blob/master/Source/WriteableBitmapEx/WriteableBitmapShapeExtensions.cs used under the MIT license 

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
        if (xl != xr) && (yt != yb) then
            puts "  Error: Designate a horizontal or vertical diameter"
            throw :script_finished
        end

        if (xl == xr) then
            #If x's equal, this is a vertical designation
            xl -= yrad
            xr += yrad	
            xrad = yrad
        else
            yt += xrad
            yb -= xrad
            yrad = xrad
        end
    end

    if mode == 'axis' then
        if (xl != xr) && (yt != yb) then
            puts "  Error: Designate a horizontal or vertical diameter"
            throw :script_finished
        end

        if (xl == xr) then
            #If x's equal, this is a vertical designation origin--major
            #find true x components
            xrad = (x2 - xl).abs
            xtemp = xl
            xl = xtemp + xrad
            xr = xtemp - xrad

        else
            #Horizontal origin--major
            #find true y components
            yrad = (y2 - yt).abs
            ytemp = yt
            yt = ytemp + yrad
            yb = ytemp - yrad
        end
    end

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

    # How far to step away from center for each side.
    awayStep = radius / thetaMax

    digAt(x0, y0, z0, digMode)

    # For every side, step around and away from center.
    # start at the angle corresponding to a distance of chord
    # away from centre.
    theta = chord / awayStep

    while (theta <= thetaMax)
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


# script execution start

if not $script_args[0] or $script_args[0]=="help" or $script_args[0]=="?" then
    puts "  To draw downstair: digshape downstair depth"
    puts "  To set origin: digshape origin"
    puts "  To draw line after origin is set: digshape line"
    puts "  To draw ellipse after origin is set (as bounding box): digshape ellipse <filled:true|false>"
    puts "  To draw a polygon after origin is set (as center) with the cursor as a vertex: digshape polygon <# sides>"
    puts "  To draw a polygon after origin is set (as center) with the cursor as a midpoint of a segment(apothem): digshape polygon <# sides> apothem"
    puts "  To draw a star after origin is set (as center) with the cursor as a vertex : digshape star <# points> <skip=2>"
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

case command
    when 'origin'
        $originx = df.cursor.x
        $originy = df.cursor.y
        $originz = df.cursor.z

        markOrigin($originx, $originy, $originz)
    when 'line'
        dig = getDigMode(argument1)

        if df.cursor.z == $originz then
            drawLine($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, dig)
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'ellipse'
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
            drawEllipse($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, filled=filled, digMode=dig)

            # remove origin designation
            digAt($originx, $originy, $originz, 'x')
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'circle2p'
        if df.cursor.z == $originz then
            drawEllipse($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, filled=filled, digMode = 'd', mode = 'diameter')	
            else
                puts "  Error: origin and target must be on the same z level"
                throw :script_finished
            end
    when 'major'
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
    when 'ellipse3p'
        if df.cursor.z == $originz then
            drawEllipse($originx, $originy, $originz, $majorx, $majory, $majorz, df.cursor.x, df.cursor.y, df.cursor.z, filled = false, digMode = 'd', mode = 'axis')
            else
                puts "  Error: origin and target must be on the same z level"
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
    when 'spiral'
        if not argument1 then
            puts "  Must supply a coils parameter"
            throw :script_finished
        else
            coils = argument1.to_i
            if coils <= 0 then
                puts "  Coils must be an integer greater than zero"
                throw :script_finished
            else
                chord = 2
                if argument2 then
                    chord = argument2.to_i
                end

                dig = getDigMode(argument3)

                drawSpiral($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.x, coils, chord, dig)
            end
        end
    else
        puts "  Error: Invalid command"
        throw :script_finished
end
