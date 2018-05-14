# dig shapes
=begin

digshape
=======

Commands that do not require a set origin:

    To dig a 3x3 sparse up-down stairway:
      digshape downstair depth

Commands that require an origin to be set:

    To set the origin for drawing:
      digshape origin

    To draw to the target point:
      digshape line
    
    To draw an ellipse using the origin and target as a bounding box:
      digshape ellipse (filled? [default: false])

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

    # find radius
    xr = ((xr - xl) / 2).ceil
    yr = ((yt - yb) / 2).ceil

    # find center
    xc = xl + xr 
    yc = yb + yr

    #TODO: ellipses can be generated such that they do not extend all the way to the edge of the bounding box. A rounding issue converting to center+radius?

    # Avoid endless loop
    if (xr < 1 || yr < 1)
        end

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
            xi = 2 * x # loop variable
            while xi > 0
                digAt(xc - x + xi, yc + y, z0, digMode)
                digAt(xc - x + xi, yc - y, z0, digMode)
                xi -= 1
            end
        else
            #hollow ellipse
            digAt(xc + x, yc + y, z0, digMode)
            digAt(xc - x, yc + y, z0, digMode)
            digAt(xc - x, yc - y, z0, digMode)
            digAt(xc + x, yc - y, z0, digMode)
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
            xi = 2 * x # loop variable
            while xi > 0
                digAt(xc - x + xi, yc + y, z0, digMode)
                digAt(xc - x + xi, yc - y, z0, digMode)
                xi -= 1
            end
        else
            #hollow ellipse
            digAt(xc + x, yc + y, z0, digMode)
            digAt(xc - x, yc + y, z0, digMode)
            digAt(xc - x, yc - y, z0, digMode)
            digAt(xc + x, yc - y, z0, digMode)
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
    while iz >= z - (depth - 1) do
        digAt(x, y, iz, 'i')
        digAt(x - 1, y + 1, iz, 'i')
        digAt(x - 1, y - 1, iz, 'i')
        digAt(x + 1, y + 1, iz, 'i')
        digAt(x + 1, y - 1, iz, 'i')
        iz -= 1
    end
end


# script execution start

if not $script_args[0] then
    puts "  To draw downstair: digshape downstair depth"
    puts "  To set origin: digshape origin"
    puts "  To draw line after origin is set: digshape line"
    puts "  To draw ellipse after origin is set (as bounding box): digshape ellipse <filled:true|false>"
    puts "  All commands accept a one letter digging designation [dujihrx], or will default to 'd'"
    throw :script_finished
end

command = $script_args[0]
argument1 = $script_args[1]
argument2 = $script_args[2]

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
        targetx = df.cursor.x
        targety = df.cursor.y
        targetz = df.cursor.z

        dig = 'd'
        case argument1
            when 'd'; dig = 'd'
            when 'u'; dig = 'u'
            when 'j'; dig = 'j'
            when 'h'; dig = 'h'
            when 'x'; dig = 'x'
            else
                dig = 'd'
        end

        if targetz == $originz then
            drawLine($originx, $originy, $originz, targetx, targety, targetz, dig)
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end
    when 'ellipse'
        targetx = df.cursor.x
        targety = df.cursor.y
        targetz = df.cursor.z

        filled = false
        dig = 'd'

        case argument1
            when 'filled'; filled = true
            when 'hollow'; filled = false
            when 'true'; filled = true
            when 'false'; filled = false
            when 'd'; dig = 'd'
            when 'u'; dig = 'u'
            when 'j'; dig = 'j'
            when 'h'; dig = 'h'
            when 'x'; dig = 'x'
        end

        case argument2
            when 'd'; dig = 'd'
            when 'u'; dig = 'u'
            when 'j'; dig = 'j'
            when 'h'; dig = 'h'
            when 'x'; dig = 'x'
            else
                dig = 'd'
        end

        if targetz == $originz then
            drawEllipse($originx, $originy, $originz, targetx, targety, targetz, filled, dig)
            digAt($originx, $originy, $originz, 'x')
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
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
