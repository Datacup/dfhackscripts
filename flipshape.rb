# dig shapes
=begin

flipshape
=======

Currently only Bresenham's line algorithm

To set the origin for drawing:
  flipshape origin

To draw to the target point:
  flipshape line

=end

if not $script_args[0] then
    puts "  To set origin: flipshape origin"
    puts "  To draw line after origin is set: flipshape line"
    throw :script_finished
end
command = $script_args[0]

if df.cursor.x == -30000 then
    puts "  Error: cursor must be on map"
    throw :script_finished
end

def markOrigin(ox, oy, oz)
    t = df.map_tile_at(ox, oy, oz)
    s = t.shape_basic
    t.dig(:Default) if s == :Wall
end

def digAt(x, y, z)
    t = df.map_tile_at(x, y, z)
    s = t.shape_basic
    t.dig(:Default) if s == :Wall
end

# https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
def drawLineLow(x0, y0, z0, x1, y1, z1)
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
        digAt(x, y, z0)
        if d > 0 then
            y = y + yi
            d = d - 2*dx
        end
        d = d + 2*dy
        x += 1
    end
end

def drawLineHigh(x0, y0, z0, x1, y1, z1)
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
        digAt(x, y, z0)
        if d > 0 then
            x = x + xi
            d = d - 2*dy
        end
        d = d + 2*dx
        y += 1
    end
end

def drawLine(x0, y0, z0, x1, y1, z1)
    if (y1 - y0).abs < (x1 - x0).abs then
        if x0 > x1 then
            drawLineLow(x1, y1, z1, x0, y0, z0)
        else
            drawLineLow(x0, y0, z0, x1, y1, z1)
        end
    else
        if y0 > y1 then
            drawLineHigh(x1, y1, z1, x0, y0, z0)
        else
            drawLineHigh(x0, y0, z0, x1, y1, z1)
        end
    end
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

        if targetz == $originz then
            drawLine($originx, $originy, $originz, targetx, targety, targetz)
        else
            puts "  Error: origin and target must be on the same z level"
            throw :script_finished
        end

    else
        puts "  Error: Invalid command"
        throw :script_finished
end