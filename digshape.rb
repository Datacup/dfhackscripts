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

def drawEllipse(x0, y0, z0, x1, y1, z1, filled = false, digMode = 'd')
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
    xr = ((xr - xl) / 2).ceil
    yr = ((yt - yb) / 2).ceil

    # find center
    xc = xl + xr 
    yc = yb + yr

    # Avoid endless loop
    return if (xr < 1 || yr < 1)

    # Init vars
    x = xr
    y = 0
    xrSqTwo = xr * xr * 2
    yrSqTwo = yr * yr * 2
    xChg = yr * yr * (1 - (xr * 2))
    yChg = xr * xr
    err = 0
    xStopping = yrSqTwo * xr
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
    y = yr
    xChg = yr * yr
    yChg = xr * xr * (1 - (yr *2))
    err = 0
    xStopping = 0
    yStopping = xrSqTwo * yr

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

def drawPolygon(x0, y0, z0, x1, y1, z1, n = 3, digMode = 'd', apothem=false)
   # if n < 3 then
   #     n = 3
   # end
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

# script execution start

if not $script_args[0] then
    puts "  To draw downstair: digshape downstair depth"
    puts "  To set origin: digshape origin"
    puts "  To draw line after origin is set: digshape line"
    puts "  To draw ellipse after origin is set (as bounding box): digshape ellipse <filled:true|false>"
    puts "  All commands accept a one letter digging designation [dujihrx], or will default to 'd'"
	#todo: someone add message for polygon
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
            drawEllipse($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, filled, dig)

            # remove origin designation
            digAt($originx, $originy, $originz, 'x')
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
            dig = getDigMode(argument3)
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
                drawPolygon($originx, $originy, $originz, df.cursor.x, df.cursor.y, df.cursor.z, n, dig, apothem)
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
    else
        puts "  Error: Invalid command"
        throw :script_finished
end
