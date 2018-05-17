# Some DFHack scripts

Some dfhack scripts from friends of keupo on twitch
# Usage
*note*: any of the drawing commands can be appended with a digging designation [dujihrx] at the end, or will default to 'd'

for example, `digshape star 5 2 j` will dig a 5 pointed star out of downstairs with the mark as the center and the cursor as a vertex on the star

## in-game help
`digshape ?`

## set mark
	digshape origin

## draw a line
	digshape line
*from cursor to mark*

## draw an ellipse
	digshape ellipse [filled]
*cursor and mark as bounding box*

## draw an ellipse by axis
        digshape major
*set the major axis from origin to mark, must be horizontal or vertical*

        digshape ellipse3p [filled]
*draw ellipse using marked major axis and current point as the minor axis radius*

## draw a circle
        digshape circle2p [filled]
*draw a circle using origin and mark as a diameter*

## draw a polygon with cursor as vertex
	digshape polygon <n sides>
*mark as center and cursor as a vertex*

## draw a polygon with cursor as apothem
	digshape polygon <n sides> apothem
*mark as center and cursor as a midpoint*

## draw a star polygon
	digshape star <n sides> [skip=2]
in [Schläfli symbol notation](https://en.wikipedia.org/wiki/Schl%C3%A4fli_symbol)
*mark as center and cursor as a vertex*


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
	
