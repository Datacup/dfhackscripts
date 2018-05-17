# Usage

You can add a digging designation to the end of any of the drawing commands - [dujihrx].  The default is 'd'.

For example, `digshape star 5 2 j` will dig a 5 pointed star out of downstairs with the mark as the center and the cursor as a vertex on the star

## In-game help
    digshape ?

## Set the origin
    digshape origin

## Draw a line
    digshape line
*from cursor to mark*

## Draw an ellipse
    digshape ellipse
*cursor and mark as bounding box*

## Draw a polygon with cursor as vertex
    digshape polygon <n sides>
*mark as center and cursor as a vertex*

## Draw a polygon with cursor as apothem
    digshape polygon <n sides> apothem
*mark as center and cursor as a midpoint*

## Draw a star polygon
In [Schläfli symbol notation](https://en.wikipedia.org/wiki/Schl%C3%A4fli_symbol)
*mark as center and cursor as a vertex*

    digshape star <n sides> [skip=2]


## Draw an Archimedean spiral with specified number of "coils", each point separated by "chord" tiles
    digshape spiral <coils> <chord>

# Contributors

- flipvine
- Qvatch
- keupo
- flavorstreet

# Resources of interest

[DFHack Lua API](https://github.com/DFHack/dfhack/blob/master/docs/Lua%20API.rst)

[DFHack dig plugin - digcircle](https://github.com/DFHack/dfhack/blob/master/plugins/dig.cpp#L402)

[Bresenham's line algorithm](https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm)

[A Fast Bresenham Type Algorithm For Drawing Ellipses](http://homepage.smc.edu/kennedy_john/belipse.pdf),
[alternate link](https://www.dropbox.com/s/3q89g566u115g3q/belipse.pdf?dl=0), also in [resources/belipse.pdf](resources/belipse.pdf)

[Writeable Bitmap Shape Extensions](https://github.com/teichgraf/WriteableBitmapEx/blob/master/Source/WriteableBitmapEx/WriteableBitmapShapeExtensions.cs) used under the MIT license 

[Drawing equidistant points on a spiral](https://stackoverflow.com/questions/13894715/draw-equidistant-points-on-a-spiral)
