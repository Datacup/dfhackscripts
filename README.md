# Usage

You can add a digging designation to the end of any of the drawing commands - [dujihrx].  The default is 'd'.

For example, `digshape star 5 2 j` will dig a 5 pointed star out of downstairs with the mark as the center and the cursor as a vertex on the star

## In-game help
    digshape ?

## Set the origin
    digshape origin

*The origin is used for most drawing operations. It persists between operations. It is Step 1 in any of the following operations.*

## draw a line
	digshape line
*draws a straight line from cursor to mark*

## draw an ellipse
	digshape ellipse [filled]
*Step 2: draw an ellipse contained within the bounding box formed of the mark and current cursor.*

### draw an ellipse using 3 pt
	digshape major  
*Step 2: set the end of the major axis from mark to cursor.*

	digshape ellipse3p
*Step 3: draw the ellipse using new cursor as the semiminor axis length (midpoint of major axis->cursor)*  
*Note: ellipse3p cannot yet be filled by an argument, use flood*

## draw a circle with arbitrary diameter
	digshape circle2p
*Step 2: mark and cursor form the diameter of the circle (at any tilt).*

## draw a 3 pt bezier curve
	digshape major
*Step 2: set the endpoint of the curve*

	digshape bez [sharpness=1.5]
*Step 3: draw the curve between mark and endpoint, pulled towards the cursor. A weight may be specified to adjust the sharpness of the curve [0=straight line, large number=hairpin).*

_eg:_ draw a bezier curve\
Step 1: place start of curve at cursor: `digshape origin`\
Step 2: move cursor to end of curve, then: `digshape major`\
Step 3: move cursor to the side of the line to be the control point for the curve, then: `digshape bez`, or `digshape bez 9` for a curve that gets closer to the cursor.

## draw a polygon with cursor as vertex
	digshape polygon <n sides>
*Step 2: draw a polygon with  sides using the mark as center and cursor as a vertex*

_eg:_ `digshape polygon 5 h`: draws a pentagram of channel designations, with the mark as the center, and the cursor as one of the verticies. \
_eg:_ `digshape polygon 6`: draws a hexagon of dig designations, with the mark as the center, and the cursor as one of the verticies.

## draw a polygon with cursor as apothem
	digshape polygon <n sides> apothem
*Step 2: Draw a polygon with n sides, with the mark as center, and cursor as a midpoint of one of the sides [apothem, like a radius]*

## Draw a star polygon
In [Schläfli symbol notation](https://en.wikipedia.org/wiki/Schl%C3%A4fli_symbol)
*mark as center and cursor as a vertex*
    digshape star <n sides> [skip=2]

## draw a point with n-fold symmetry
	digshape star <n sides> <n sides>
*Step 2: draw a point at the cursor, and at n points around the origin at the same radius, as though they were verticies of a star without drawing the connecting lines. (eg for 5fold: "digshape star 5 5"). It is helpful to bind this to a keycombo, so that it can be used to draw.*

## Draw an Archimedean spiral with specified number of "coils", each point separated by "chord" tiles
    digshape spiral <coils> <chord>

## flood fill an area
        digshape flood [max coverage=10000]
*Fill an area with a dig designation. Will only fill tiles that match the designation under the cursor. Ignores/does not require the origin to be set.*  
*Note: Larger max coverages can take time to fill. A great way to fill in the above shapes.*

## undo last digshape command
        digshape undo
*restores designations for the last digshape command. Will not record manual or other commands designations, but won't loose it's record.*

## move all markers to the current z level
        digshape resetz
*moves the markers (origin, major) to the current z level*


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
