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

### draw an ellipse using 3 pt
	digshape major  
*set the end of the major axis from origin to mark*

	digshape ellipse 3p
*draw the ellipse using new cursor as the semiminor axis length (center->cursor)*
*Note: ellipse3p cannot yet be filled*

## draw a circle with arbitrary diameter
	digshape circle 2p
*cursor and mark form the diameter of the circle (at any tilt)*

## draw a 3 pt bezier curve
	digshape major
*set the end point of the curve*

	digshape bez [sharpness=1.5]
*draw the curve between mark and endpoint, pulled towards the cursor. A weight may be specified to adjust the sharpness of the curve.*

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

[A Rasterizing Algorithm for Drawing Curves](http://members.chello.at/easyfilter/bresenham.pdf)

[Writeable Bitmap Shape Extensions](https://github.com/teichgraf/WriteableBitmapEx/blob/master/Source/WriteableBitmapEx/WriteableBitmapShapeExtensions.cs) used under the MIT license 

[Drawing equidistant points on a spiral](https://stackoverflow.com/questions/13894715/draw-equidistant-points-on-a-spiral)
	
