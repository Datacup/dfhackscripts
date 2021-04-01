--gui front-end for digshape.rb, a geometric designations generating tool
--[====[

gui/digshape
===========
gui front-end for digshape.rb, a geometric designations generating tool

--todo: mousemode. mouse: click1 set origin; click1 again: set cursor, commmit
]====]

verbose = false --TODO: move these down later to be arguments
--dfhack.screen.invalidate() --force an immediate redraw.
--TODO: use dfhack.print(args...) for better printing

function printtable(table, note, recursecount, recurselimit)
    --pretty print a table, adds $note and source line number as a header
    --printall_recurse(obj)..sigh. Why couldn't I find this when I went looking for it.
    if not verbose then
        return
    end
    local prefix = note or "|"
    local recursecount = recursecount or 5
    local title = ""
    if not string.match(prefix, "^ *|$") then
        title = "  " .. prefix .. "  "
        prefix = "|"
    end

    if recursecount <= 0 then
        print(prefix .. "-->> MAX DEPTH <<--")
        return
    end

    if prefix == "|" then
        dfhack.color(COLOR_LIGHTGREEN)--reset colour
        dfhack.println("=PRINT=TABLE=" .. title .. "============ <<digshape.lua (" .. debug.getinfo(2).currentline .. ")>>")
        dfhack.color(nil)--reset colour
    end
    if type(table) ~= "table" then
        print("->>" .. prefix .. table)
        return
    end
    print(string.gsub(prefix, "|", "") .. "@>-----------------@")
    for k, v in pairs(table) do
        if type(v) ~= "table" then
            print(prefix .. "[" .. k .. "]:  <" .. tostring(v) .. ">")
        else
            print(prefix .. "[" .. k .. "]:  ")--.. "<table>:")
            printtable(v, "  " .. prefix, recursecount - 1) --indent prefix and recurse. Yes, no sanity checking, user knows when to use, not for production.
        end
    end
    print(string.gsub(prefix, "|", "") .. "@<-----------------@")
    dfhack.color(nil)--reset colour
end

--[[
=======Useful dfhack tidbits========
"kill-lua": kills running lua scripts, opt: "force"
"devel/pop-screen": exit an active gui script
"devel/clear-script-env SCRIPTNAME"
"lua onelinescript........": run a lua command directly.
    ----"lua _G.digshape-gui_saved_options=nil": clears digshapegui's special save
"devel/click-monitor start|stop" : prints coordinates of mouse clicks to console

=====Console color constants
COLOR_RESET = -1
COLOR_BLACK = 0
COLOR_BLUE = 1
COLOR_GREEN = 2
COLOR_CYAN = 3
COLOR_RED = 4
COLOR_MAGENTA = 5
COLOR_BROWN = 6
COLOR_GREY = 7
COLOR_DARKGREY = 8
COLOR_LIGHTBLUE = 9
COLOR_LIGHTGREEN = 10
COLOR_LIGHTCYAN = 11
COLOR_LIGHTRED = 12
COLOR_LIGHTMAGENTA = 13
COLOR_YELLOW = 14
COLOR_WHITE = 15

====GUI stuff
Lua api: https://docs.dfhack.org/en/stable/docs/Lua%20API.html#
1st half of GUI module: https://docs.dfhack.org/en/stable/docs/Lua%20API.html#gui-module
2nd half of GUI module: https://docs.dfhack.org/en/stable/docs/Lua%20API.html#screen-api
3rd half of GUI module: https://docs.dfhack.org/en/stable/docs/Lua%20API.html#in-game-ui-library
Painter: https://docs.dfhack.org/en/stable/docs/Lua%20API.html#painter-class
Widgets: https://docs.dfhack.org/en/stable/docs/Lua%20API.html#gui-widgets
See also: dfhack.lua, class.lua, dwarfmode.lua, gui.lua, widgets.lua, dialogs.lua as the html helpfiles do not adaquately describe the functionality.

====Label widget:
Label.ATTRS{
    text_pen = COLOR_WHITE,
    text_dpen = COLOR_DARKGREY, -- disabled
    text_hpen = DEFAULT_NIL, -- highlight - default is text_pen with reversed brightness
    disabled = DEFAULT_NIL,
    enabled = DEFAULT_NIL,
    auto_height = true,
    auto_width = false,
    on_click = DEFAULT_NIL,
    on_rclick = DEFAULT_NIL,
}
--]]

local utils = require "utils"
local gui = require "gui"
local guidm = require "gui.dwarfmode"
local dialog = require "gui.dialogs"
local widgets = require 'gui.widgets'

stdout = function(msgtype, ...)
    if type(msgtype) == "string" then
        local _, _, temp = string.find(msgtype, "^(...)$")
        if temp == "OUT" then
            --only print the final output
            dfhack.color(COLOR_WHITE)
            dfhack.print(msgtype:sub(4))
            dfhack.println(...)
            dfhack.color(nil)
        end
    end
end--silently discard everything but output.

if verbose then
    --atm verbose must be set manually, see line2 of this script.
    dfhack.console.clear()
    stdout = function(msgtype, ...)
        --A stupid pretty console print command.
        local prefix = "DS/UI" .. "(" .. debug.getinfo(2).currentline .. "): "
        if type(msgtype) == "string" then
            local _, _, temp = string.find(msgtype, "^(...)$")
            if temp == "ERR" or temp == "MSG" or temp == "WRN" or temp == "OUT" or temp == "CMD" or temp == "RBY" or temp == ">>>" or temp == "CAL" then
                --output channels: MSG/WRN/ERR: information, OUT: results, RBY: digshape output passed through.
                if temp == "IGNORE" or temp == "ALSOIGNORE" or temp == "RBY5" then
                    return --don't print
                end
                local color = { RBY = COLOR_DARKGREY, MSG = COLOR_WHITE, WRN = COLOR_YELLOW, ERR = COLOR_LIGHTRED, CMD = COLOR_LIGHTCYAN, OUT = COLOR_MAGENTA, [">>>"] = COLOR_LIGHTMAGENTA, CAL = COLOR_BROWN }
                dfhack.color(color[temp])

                if verbose == false and temp ~= "ERR" then
                    return --only print errors when not verbose
                end

                --[[                if temp=="CAL" then
                                    temp=
                                    if temp ~=nil then
                                        msgtype=msgtype.."@ "..temp

                                    end
                                end]]

                prefix = prefix .. msgtype .. ": "
                msgtype = ""
                --else
                --    prefix = " DS: "
            end

        end
        dfhack.print(prefix .. msgtype)--
        dfhack.println(...)
        dfhack.color(nil)--reset colour
    end
    --TOOD: fancy! https://www.lua.org/pil/6.html
else
    -- print=nil --suckers, don't print anything.
end

--stdout("gui/Digshape verbose output"," ".."!")
--stdout("ERR", "gui/Digshape verbose output"," ".."!")
--stdout("ERR", "A", "B", "C","D".."D")
--stdout("A", "B", "C","D".."D")

--[[ TODO: split DigshapeUI into UI and I:
DigshapeInterface = defclass(DigshapeInterface) --a class to hold the digshape specific stuff, the translation and parsing stuff, rather than the UI/display stuff
This may get us a readOnly attr set for each command/command specific persistance if we make a new copy of this for each command.

DigshapeInterface.ATTRS {}
DigshapeInterface:nameCommand(string)--extract the name command (eg "digshape lua preview ellipse bbox hollow d" -> "ellipse"), should this check the commandBase arg to translate?
DigshapeInterface:parseCommand(string) -- strip any UI only args, put into form that digshape will accept. Add "digshape lua", "preview" or not should be done by UI.
DigshapeInterface:runDigshapeCommand()
]]



DigshapeUI = defclass(DigshapeUI, guidm.MenuOverlay)

DigshapeUI.ATTRS {
    state = "preview",
    activeDesgination = 'd',
    activeCommand = { name = "spiral", args = {}, digshapeArgs = { fill = "NA", digmode = "@", mode = "designating" }, digshapeString = "" },
    resetActiveCommand = function()
        return { name = "spiral", args = {}, digshapeArgs = { fill = "NA", digmode = "@", mode = "designating" }, digshapeString = "" }
    end,
    --currentCommand = 'spiral', --TODO: replace this with self.activeCommand.name
    --parsedCommand = DEFAULT_NIL, --TODO: move this to self.activeCommand.name.parsedCommand

    --currentOutput = {},
    --currentError = {},
    --currentDig = {},
    origin = nil,
    major = nil,
    autosetZtoCurrent = true,
    -- default properties for self here

    --Preview mode variables
    blink = false, --should the preview blink?
    blinkrate = { 3, 750, 350, 125 }, --how fast do we blink. blinkrate[1] is the index of the chosen rate.
    pens = {
        --{key, symbol character code, fgcolor, bgcolor}
        --https://docs.dfhack.org/en/stable/docs/Lua%20API.html#pen-api

        --tiles and map icons
        origin = dfhack.pen.make({ ch = '+', fg = COLOR_CYAN, bg = COLOR_LIGHTGREEN }),
        cursor = dfhack.pen.make({ ch = 'X', fg = COLOR_CYAN, bg = COLOR_BLACK }),
        ctrl_A = dfhack.pen.make({ ch = 'a', fg = COLOR_CYAN, bg = COLOR_LIGHTCYAN }),
        designation = dfhack.pen.make({ fg = COLOR_BROWN, bg = COLOR_YELLOW }),
        mark = dfhack.pen.make({ fg = COLOR_YELLOW, bg = COLOR_LIGHTCYAN }),
        clear = dfhack.pen.make({ fg = COLOR_BROWN, bg = COLOR_RED }),

        --digmode menu
        digMode = {
            selected = dfhack.pen.make({ fg = COLOR_BLACK, bg = COLOR_LIGHTGREEN }),
            deselected = dfhack.pen.make({ fg = COLOR_LIGHTGREEN, bg = COLOR_BLACK }),
            delete = dfhack.pen.make({ fg = COLOR_BLACK, bg = COLOR_LIGHTRED }),
            mark = dfhack.pen.make({ fg = COLOR_BLACK, bg = COLOR_LIGHTCYAN }),
        },

        --other menu
        enabledMenu = dfhack.pen.make({ fg = COLOR_GREY, bg = COLOR_BLACK }), --visible and interactable
        disabledMenu = CLEAR_PEN, --visible but locked
        alertMenu = dfhack.pen.make({ fg = COLOR_DARKGREY, bg = COLOR_RED }), --visible and redbackground for required input
    },

    --Designation mode variables (to be saved between commands)
    -- designateDigMode = {}, --what is the UI selected digMode?
    --designateMarking = false, --are we designating "marking" rather than standard?
    --designateFilled = false, --filled or hollow? (will be ignored if current command does not allow/use it)



    digButtons = {
        --, keypen={selected=self.pens.digMode.,deselected=self.pens.digMode.,}},
        d = { key = 'd', symbol = " ", text = "Mine", },
        i = { key = 'i', symbol = "X", text = "U/D Stair" },
        h = { key = 'h', symbol = "_", text = "Channel" },
        r = { key = 'r', symbol = 30, text = "Up Ramp" },
        j = { key = 'j', symbol = ">", text = "Down Stair" },
        u = { key = 'u', symbol = "<", text = "Up Stair" },
        x = { key = 'x', symbol = " ", text = "Remove Designation" },
        M = { key = 'M', symbol = " ", text = "Toggle Dig/Mark" },
        order = "_dihrjuxM_", --we need to know the order so we can insert/remove cursor markers in the designation list. It's a hack, sorry.
    },


    --Digshape command reference
    digshapeCommands = {
        --[[
        --This table records the names, requiremens, and arguments for each digshape command.

        --todo: make this read only so we can reset to defaults. Dunno. Maybe https://www.lua.org/pil/13.4.5.html? maybe there's a idiomatic way.

        --requireOrigin[bool]: do we need the origin to be set?
        --requireMajor[bool]: " controlPointA (major) set?
        --requireZ[bool]: " cursor/view on same z as origin/controlPoints?
        --allowFilled[bool]: Can this command accept filled/hollow? (eg. "line" has no volume and so cannot be either).
        --runSilent[bool]: should this command always be run silent? --TODO: I don't use this yet, and don't quite remember why I thought we needed it.
        --digMode [string OR nil]: what the digMode is allowed to be. "@": any, "nil": none, "[character]": this/these and only these.
        --desc: Short description of this command, used as in-game help.
        --args [{{}{}...{}} OR nil]: details on the arguments to this command. If no args accepted, args=nil
        -- --args element[{}]: details on one argument to a digshape command
        -- -- --name[string]: name for this argument, used as in-game display
        -- -- --required[bool]: does digshape require we pass this arg? Almost always true atm.
        -- -- --desc[string]: short description of what this argument controls, used for in-game help.
        -- -- --default[any valid OR nil OR {}]: the default value for this arg if not supplied by user. If a {}, then should contain validity checking:
        -- -- -- --default=[any]: the actual default value, only if args.default={}
        -- -- -- --min=[numeric]: lower (inclusive) bound on value. If not present, then value can be lowered to min(type)
        -- -- -- --max=[numeric]: upper (inclusive) bound on value. If not present, then value can be raised to max(type)
        -- -- -- --values=[{} OR string]: ordered list of ONLY acceptable values. If a string, treated as lua String.Pattern that must match entire value.
        -- -- -- --type=[string: "int, float, bool, string, pos, luatable"]: what data type is acceptable, only one type is allowed.
        -- -- -- --inc=[numeric]: what is the default +- amount to change this value by when adjusted by GUI. If values={}, increment must be int,and is the number of indicies to advance(% len). TODO: SHIFT-inc: *2, CTRL-inc: *5, ALT-inc: /10; modifiers stack.
        --]]

        --COMMAND={requireOrigin = false, requireMajor = false, requireZ = false, allowFilled = false, args = {name="",required=true,default=nil,type="",desc=""}, runSilent = true, digMode = nil, desc = "Set the origin"},

        origin = { requireOrigin = false, requireMajor = false, requireZ = false, allowFilled = false, args = nil, runSilent = true, digMode = nil, desc = "Set the origin" },
        controla = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Set the first control point (A, or 'major')" },
        swap = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Swap the origin and cursor" },

        allCommands = { requireOrigin = true, requireMajor = false, requireZ = false, allowFilled = false, args = { "command", default = "circle", values = { "circle", "line", "curve", "ellipse", "star", "polygon", "spiral" }, commandBase = { "circle", "line", "curve", "ellipse", "star", "polygon", "spiral" }, type = "string", runSilent = false, digMode = "@", desc = "Command selection" }, },

        circle = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Draw a circle", aliases = { "c", "c2", "circle2p" } },

        line = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = nil, runSilent = false, digMode = "@", desc = "Draw a line", aliases = { "l", "ray" } },

        ellipse = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "mode", required = true, default = { default = "bbox", values = { "bbox", "2axis" }, commandBase = { "ellipse", "ellipse3p" }, inc = 1 }, type = "string", desc = "Method of layout", guiOnlyArg = true } }, runSilent = false, digMode = "@", desc = "Draw a ellipse", aliases = { "e" } }, --default.commandBase is used to call different commands when the mode argument is cycled. Used in runCurrentCommand()

        ellipse3p = { requireOrigin = true, requireMajor = true, requireZ = true, allowFilled = false, args = { { name = "mode", required = true, default = { default = "2axis", values = { "bbox", "2axis" }, commandBase = { "ellipse", "ellipse3p" }, inc = 1 }, type = "string", desc = "Method of layout", guiOnlyArg = true } }, runSilent = false, digMode = "@", desc = "Draw a ellipse", aliases = { "e3" } }, --crude hack to allow ellipse and ellipse3p to switch named on the arg.

        polygon = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "sides", required = true, default = 3, type = "int", desc = "Number of sides of the polygon" }, { name = "vertex", required = true, default = false, type = "bool", desc = "Is the cursor on a vertex, or the midpoint of a side?" }, }, runSilent = false, digMode = "@", desc = "Draw a polygon", aliases = { "p", "poly", "ngon" } },

        star = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "points", required = true, default = 5, type = "int", desc = "Number of points of the star" }, { name = "skip", required = true, default = 2, type = "int", desc = "How many to skip when connecting...?" }, }, runSilent = false, digMode = "@", desc = "Draw a star", aliases = { "s", "st" } },

        spiral = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "coils", required = true, default = 2, type = "int", desc = "Number of turns the spiral makes." }, { name = "skip", required = true, default = 1, type = "int", desc = "Draw every # points along spiral." }, { name = "rotate", required = true, default = { default = 0, mod = 360, inc = 15, type = "int" }, type = "int", desc = "Rotate the spiral, 0-360." }, }, runSilent = false, digMode = "@", desc = "Draw a spiral", aliases = { "sp", "coil" } },

        flood = { requireOrigin = false, requireMajor = false, requireZ = false, allowFilled = false, args = { { name = "max", required = false, default = 10000,inc=5000, type = "int", desc = "Maximum number of tiles filled before aborting. Larger numbers just take longer to complete." }, { name = "diagonals", required = false, default = false, type = "bool", desc = "Should the flood escape through corners?",guiOnlyArg=true }, }, runSilent = false, digMode = "@", desc = "Floodfill current designation at cursor.",aliases={"f"} },

        resetz = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Move all control points to current z level",aliases={"z"} },
        radial = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = { { name = "ways", required = true, default = 3, type = "int", desc = "Number of radially symetrical points to draw." }, }, runSilent = false, digMode = "@", "Draw points with radial symmetry around origin" }, --todo: code this
        curve = { requireOrigin = true, requireMajor = true, requireZ = true, allowFilled = false, args = { { name = "Sharpness", required = true, default = { default = 1.5, min = 0, max = 100, inc = 0.1, type = "float" }, type = "float", desc = "How strongly the curve is pulled towards the cursor" } }, runSilent = false, digMode = "@", desc = "Draw a curve (bezier) from origin to major pulled towards cursor" }, --todo: allow filled. Also draw line, then fill shape
        --{ default = 1.5, min = 0, max = 100, inc = 0.1, type = "float" }
        --arc = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false,digMode="@",desc="Draw an arc from origin to major passing through cursor." },
        downstair = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "depth", required = true, default = 10, type = "int", desc = "Number of z levels down to designate." }, { name = "start", required = true, default = true, type = "bool", desc = "Should the starting level be updown [false] or down [true]" }, }, runSilent = false, digMode = "@", desc = "Designate a 3x3 block of updown stairs, corners and center only",aliases={"k","ks"} },
    },


    --Mouse variables
    mouse = true,
    mousebuttons = { 'commit', 'origin', 'major' },
    dragging = false,
    lastMouse = xyz2pos(0, 0, 0),
    lerp = true, --lerp is laggy because it repeatedly inefficiently accesses memory; it would be faster if we cached some but thats above my paygrade ;)
    customOffset = { x = 0, y = 0 },
}

function DigshapeUI:init()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    self.saved_mode = df.global.ui.main.mode
    df.global.ui.main.mode = df.ui_sidebar_mode.LookAround

    --grab the current digshape status
    self:runDigshapeCommand("digshape lua status")

    --set up the layout of the menu
    self:addviews {

        widgets.Label {
            frame = { t = 3, l = 1 }, --place it inset one tile off the bottom left
            view_id = "controlPointsMenu",
            text = {
                { key = "CUSTOM_O", text = "Set origin", key_sep = ": ",
                  on_activate = self:callback('buttonCallback_setOrigin')
                }, NEWLINE,

                { key = "CUSTOM_S", text = "Swap origin/cursor", key_sep = ": ",
                  on_activate = self:callback('buttonCallback_swapOrigin')
                }, NEWLINE,

                { key = "CUSTOM_A", text = "Set major", key_sep = ": ", id = "button_setCtrlA",
                  on_activate = self:callback('buttonCallback_setControlA')
                }, NEWLINE,

                { id = "button_toggleFill", key = "CUSTOM_F", text = "Toggle fill: " .. self:getCurrentFill(), key_sep = ": ",
                  on_activate = self:callback('buttonCallback_toggleFilled')
                }, NEWLINE,
            },
        },


        widgets.Label {
            frame = { t = 9, l = 1 }, --place it inset one tile off the bottom left
            view_id = "digshapeMenu",
            text = {
                { key = "CUSTOM_P", text = "Set digshape command", key_sep = ": ",
                  on_activate = self:callback('buttonCallback_setCommand'),
                }, NEWLINE,
                {text="[ ", pen = COLOR_YELLOW, gap = 2},
                { text = "[ digshape command ]", pen = COLOR_YELLOW, id = "label_digshapeCommand" },
                {text=" ]", pen = COLOR_YELLOW},NEWLINE,
                NEWLINE,


                --------------Arg 1
                { key = "SECONDSCROLL_UP", key_sep = ",", id = "button_arg1dec",
                  on_activate = self:callback('buttonCallback_argAdjust', 1, "-", 1)

                },
                { key = "SECONDSCROLL_DOWN", id = "button_arg1inc",
                  on_activate = self:callback('buttonCallback_argAdjust', 1, "+", 1)

                },
                { text = ": ", id = "label_arg1sepA", }, --Adjust: "},
                { text = "ARG1NAME", id = "label_arg1name", width = 8, pad_char = ".", },
                { text = ":  [ ", id = "label_arg1sepB", },
                { text = "#", id = "label_arg1value" },
                { text = " ]", id = "label_arg1sepC", },
                NEWLINE,

                --------------Arg 2
                { key = "SECONDSCROLL_PAGEUP", key_sep = ",", id = "button_arg2dec",
                  on_activate = self:callback('buttonCallback_argAdjust', 2, "-", 1)

                },
                { key = "SECONDSCROLL_PAGEDOWN", id = "button_arg2inc",
                  on_activate = self:callback('buttonCallback_argAdjust', 2, "+", 1)

                },
                { text = ": ", id = "label_arg2sepA", }, --Adjust: "},
                { text = "ARG2NAME", id = "label_arg2name", width = 8, pad_char = ".", },
                { text = ":  [ ", id = "label_arg2sepB", },
                { text = "#", id = "label_arg2value" },
                { text = " ]", id = "label_arg2sepC", },
                NEWLINE,

                --------------Arg 3
                { key = "STRING_A091", key_sep = ",", id = "button_arg3dec", --STANDARDSCROLL_UP
                  on_activate = self:callback('buttonCallback_argAdjust', 3, "-", 1)

                },
                { key = "STRING_A093", id = "button_arg3inc",
                  on_activate = self:callback('buttonCallback_argAdjust', 3, "+", 1)

                },
                { text = ": ", id = "label_arg3sepA", }, --Adjust: "},
                { text = "ARG3NAME", id = "label_arg3name", width = 8, pad_char = ".", },
                { text = ":  [ ", id = "label_arg3sepB", },
                { text = "#", id = "label_arg3value" },
                { text = " ]", id = "label_arg3sepC", },
                NEWLINE,


                --[[                { key = "CUSTOM_SHIFT_P", text = "Reset arguments", key_sep = ": ", id = "button_resetArgs",
                                  on_activate = self:callback('buttonCallback_argAdjust', -1, "reset")
                                    --self:callback('buttonCallback_setCommand')("Q1")
                                }, NEWLINE,]]

            }
        },

        widgets.Label {
            frame = { t = 18, l = 1 },
            view_id = "digmodeMenu",
            text = {
                { text = "Set Designation:" },
                NEWLINE,
                { text = "[" }, --Adjust: "},Designate:
                { text = "", id = "label_digmodeStart" },
                { key = "CUSTOM_D", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'd'), id = "button_digmode_d",
                    --pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=true,
                },
                { key = "CUSTOM_I", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'i'), id = "button_digmode_i",
                    -- pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                { key = "CUSTOM_H", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'h'), id = "button_digmode_h",
                    --pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                { key = "CUSTOM_R", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'r'), id = "button_digmode_r",
                    -- pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                { key = "CUSTOM_J", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'j'), id = "button_digmode_j",
                    -- pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                { key = "CUSTOM_U", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'u'), id = "button_digmode_u",
                    --  pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                { key = "CUSTOM_X", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'x'), id = "button_digmode_x",
                    -- pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                { key = "CUSTOM_SHIFT_M", text = "", key_sep = "",
                  on_activate = self:callback('buttonCallback_setDig', 'M'), id = "button_digmode_M",
                    --  pen=self.pens.digMode.selected,dpen=self.pens.digMode.deselected,enabled=false,
                },
                --NEWLINE,

                -- { text = "ARG3NAME", id = "label_arg3name" },
                --{ text = "", id = "label_digmodeEnd" },
                { text = "]: ", pen = { CLEAR_PEN, bg = COLOR_BLACK }, },
                { text = "digmode name", id = "label_digmodeName" },
                --{ text = " ]" },NEWLINE,
            },
        },

        widgets.Label {
            frame = { b = 1, l = 1 }, --place it inset one tile off the bottom left
            view_id = "bottomMenu",
            text = {
                --{ key = "HELP", text = "Help for cur. cmd.", key_sep = ": ",
                --  on_activate = self:callback('buttonCallback_showHelpPopup'),
                --}, NEWLINE,

                { key = "STRING_A092", text = "Move view to see origin", key_sep = ": ",
                  on_activate = self:callback('buttonCallback_recenterView'),
                }, NEWLINE,

                { key = "CUSTOM_Z", text = "Undo last digshape", key_sep = ": ",
                  on_activate = self:callback('buttonCallback_undo'),
                }, NEWLINE,

                { key = "SELECT", text = "Execute Command", key_sep = ": ",
                  on_activate = self:callback('buttonCallback_commit'),
                }, NEWLINE,

                { key = "LEAVESCREEN", text = "Back", key_sep = ": ",
                  on_activate = self:dismiss(),
                }, NEWLINE,
            },
        },
    }

    --if origin isn't set, just put it at the cursor
    --todo: make this a skippable option named on argument. Other values might include "here", "last", "coords"
    if self.origin == nil then
        self:runDigshapeCommand("digshape lua origin")
    end

    --assume we're always working on the current z level, todo: make this an option named on argument
    self.autosetZtoCurrent = true

    --display the current command preview
    --self:buttonCallback_setDig(self.activeDesgination)
    self:setCommand(self.activeCommand.name)
    --self:updateMenuDisplay()
    --self:previewCurrentCommand()
    --dfhack.gui.revealInDwarfmodeMap(self.origin)
end

function DigshapeUI:onDestroy()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    df.global.ui.main.mode = self.saved_mode
end

function DigshapeUI:toggleSubViewVis(viewID, setActiveByVis)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    --toggles visibility (and by default, active status) of a id'd subview.
    if self.subviews == nil then
        stdout("ERR", "View element not found:", viewID)
        return
    end
    if setActiveByVis == nil then
        setActiveByVis = true
    end
    --self.subviews[viewID]=nil
    --for i,v in ipairs(self.subviews) do
    --    if v.view_id==viewID then
    --        self.subviews[i]=nil
    --    end
    --end
    --
    self.subviews[viewID].visible = not self.subviews[viewID].visible
    if setActiveByVis then
        self.subviews[viewID].active = self.subviews[viewID].visible
    end
end

function DigshapeUI:toggleSubViewActive(viewID)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    --toggles View.Active, which can change the display, and stops it from getting keypresses.
    if self.subviews == nil then
        stdout("ERR", "View element not found:", viewID)
        return
    end
    self.subviews[viewID].active = not self.subviews[viewID].active
end

local lastX = df.global.cursor.x
local lastY = df.global.cursor.y
local lastZ = df.global.cursor.z



--local function deepcopy(orig)
--http://lua-users.org/wiki/CopyTable
--    local orig_type = type(orig)
--    local copy
--    if orig_type == 'table' then
--        copy = {}
--        for orig_key, orig_value in next, orig, nil do
--            copy[deepcopy(orig_key)] = deepcopy(orig_value)
--        end
--        setmetatable(copy, deepcopy(getmetatable(orig)))
--    else -- number, string, boolean, etc
--        copy = orig
--    end
--    return copy
--end



function DigshapeUI:updateMenuDisplay()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    -- update all arg display and value, plus major/fill;;or update given arg to current value. TODO
    local command = self.activeCommand.name
    --if command ~=self.activeCommand.name  then
    --    print(command, self.activeCommand.name, self.activeCommand.digshapeString)
    --    --stdout("WRN", "self.activeCommand.name != self.activeCommand.name",self.activeCommand.name ,self.activeCommand.name)
    --   -- printtable(self.activeCommand.name)
    --   -- worms()
    --end

    local showArgs
    showArgs = function(self, command)
        stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
        command = command or self.activeCommand.name
        -- stdout("MSG", ">showargs>" .. command.."<")
        -- print(self.activeCommand.name)
        if self.digshapeCommands[command] == nil then
            stdout("WRN", "No args for:" .. command)
            return nil
        end

        local args = self.digshapeCommands[command].args
        local ids = { "button_arg#dec", "button_arg#inc", "label_arg#name", "label_arg#sepA", "label_arg#sepB", "label_arg#sepC", "label_arg#value" }--, "button_resetArgs" }--,"label_arg#desc"}

        local nargs = 0
        if args ~= nil then
            for i, v in ipairs(args) do
                for k = 1, #ids do
                    local index = string.gsub(ids[k], "#", i)
                    -- print("vis", i, k, index)
                    self:updateMenuArg("digshapeMenu", index, { disabled = false })

                end
                --printtable(v, "ARG " .. i)
                self:updateMenuArg("digshapeMenu", "label_arg" .. i .. "name", { text = v.name })
                self:updateMenuArg("digshapeMenu", "label_arg" .. i .. "value", { text = tostring(v.currentValue) })
                nargs = nargs + 1
            end
        end

        if nargs < 3 then
            for i = nargs + 1, 3 do
                for k = 1, #ids do
                    local index = string.gsub(ids[k], "#", i)
                    --  print("hide", i, k, index)
                    self:updateMenuArg("digshapeMenu", string.gsub(ids[k], "#", i), { dpen = self.pens.disabledMenu, disabled = true })
                end

                self:updateMenuArg("digshapeMenu", "label_arg" .. i .. "name", { text = "--------" })
                self:updateMenuArg("digshapeMenu", "label_arg" .. i .. "value", { text = "-" })
            end

        end
    end
    --printtable(self.activeCommand)

    --update digshape command display
    self:rebuildDigshapeArgumentString()
    self:updateMenuArg("digshapeMenu", "label_digshapeCommand", { text = self.activeCommand.digshapeString:gsub("@",self.activeDesgination) })

    --update control point display/lockout
    showArgs(self)
    local fillToggle = self:getCurrentFill()
    self:updateMenuArg("controlPointsMenu", "button_toggleFill", { text = "Toggle fill: " .. fillToggle, disabled = (fillToggle == "NA"), dpen = self.pens.disabledMenu })

    --update setmajor display
    --printtable(self.digshapeCommands[command])
    if self.digshapeCommands[command].requireMajor then
        if self.major == nil then
            print("enable alert major")
            self:updateMenuArg("controlPointsMenu", "button_setCtrlA", { dpen = self.pens.alertMenu, disabled = false })
        end
        print("enable major")
        self:updateMenuArg("controlPointsMenu", "button_setCtrlA", { dpen = self.pens.enabledMenu, disabled = false })
    else
        --print("disable major")
        self:updateMenuArg("controlPointsMenu", "button_setCtrlA", { dpen = self.pens.disabledMenu, disabled = false })
        --don't actually disable the key, just darken it to indicate we don't need it
    end

    --update argument display
    --print(self.activeCommand.name)
    --printtable(self.activeCommand.name)
    --
    --printtable(self.digshapeCommands[self.activeCommand.name])
    --printtable(self.digshapeCommands[self.activeCommand.name].args)
    --[self.activeCommand.name]
    if self.activeCommand.args ~= nil and self.activeCommand.args ~= {} then
        showArgs(self, command)--showargs first so that preview updates their values.
    else
     --   printtable(self.activeCommand)
        stdout("WRN", "Can't update args in menu, no args set.")
    end

    --update designation display


end

--self:updateMenuArg("","",{})
function DigshapeUI:updateMenuArg(menu, textID, newvalues)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    local temp = self.subviews[menu].text_ids[textID]

    if type(newvalues) == "table" then
        if newvalues.dpen ~= nil then
            temp.dpen = newvalues.dpen
        end
        if newvalues.disabled ~= nil then
            temp.disabled = newvalues.disabled
        end
        if newvalues.text ~= nil then
            temp.text = newvalues.text
        end
    end
end

function DigshapeUI:changeCommandTo(newCommand)
    --this function is what the input prompt returns the input with. We will detect this value becoming not nil at the top of onRenderBody() and call setCommand(self.changeCommandToCommand).
    self.changeCommandToCommand = newCommand
end

function DigshapeUI:setCommand(newCommand)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    stdout(">>>", "Setcommand ---------------------")
    stdout("MSG", "Set command=", newCommand)
    local commandBase = ""
    for k, v in pairs(self.digshapeCommands) do
        if newCommand == k then
            commandBase = k
            break
        elseif v.aliases ~= nil then
            for i = 1, #v.aliases do
                if newCommand == v.aliases[i] then
                    commandBase = k
                    break
                end
            end

        end
    end
    newCommand = commandBase

    self.activeCommand.name = newCommand
    self.activeCommand.digshapeString = nil
    local command = self:parseCommand()
    self:runDigshapeCommand("digshape lua status")

    --this is the one exception to calling preview outside of onInput, as onInput has already resolved at this point. TODO: simulate input to force redraw
    self:updateMenuDisplay()
    self:previewCurrentCommand()
end

function DigshapeUI:rebuildDigshapeArgumentString()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    --does not set "digshape lua preview"
    local newstring=""
    local words = {}
    if self.activeCommand.digshapeString~=nil then
        while true do
            local w=string.gsub(self.activeCommand.digshapeString, "^(%a*)( ?.-)$","%1" )--:sub(1)
            if w=="" then
                break
            end
            table.insert(words, w)
            self.activeCommand.digshapeString=self.activeCommand.digshapeString:gsub(w,"")
        end
        newstring=words[1]
        words[1]=nil
    else
        self.activeCommand.digshapeString=""
    end

    for index,w in ipairs(words) do
        print(index, w)
        if w == "digshape" or w == "lua" or w == "preview" then
            newstring=newstring.." "..w
        end
        for k,v in pairs(self.digshapeCommands) do
            if w==k then
                newstring=newstring.." "..w:tostring()
            end
        end
    end

    if self.activeCommand.args ~= nil then
        for k,v in pairs(self.activeCommand.args) do
            --  print(k)
            -- printtable(v)
            if v.guiOnlyArg==nil then
                newstring=newstring.." "..tostring(v.currentValue)
            end
        end
    end

    --filled/hollow
    local filledstring="NA"
    if self.activeCommand.digshapeArgs.fill ~="NA" then
        filledstring=tostring(self.activeCommand.digshapeArgs.fill)
    else
        filledstring=""
    end
    newstring=newstring.." "..filledstring

    --digMode
    local digstring="@"
    if self.activeCommand.digshapeArgs.digmode ~= "@" then
        digstring=self.activeCommand.digshapeArgs.digmode
    else
        digstring=self.activeDesgination
    end
    newstring=newstring.." ".. digstring
    self.activeCommand.digshapeString=newstring
    -- = self.activeCommand.digshapeString:gsub("^((digshape )?(lua )?(preview )?(%a+)(.-)$","%1%2%3%4")
end

function DigshapeUI:clearCommand()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    stdout(">>>", "Clear Command")

    local currentFill = self.activeCommand.digshapeArgs.fill -- save this so it carries between commands
    local commandBase = self.activeCommand.name--:lower():match("^%a+")
    self.activeCommand = self.resetActiveCommand()
    self.activeCommand = { name = commandBase, args = self.digshapeCommands[commandBase].args, digshapeString = commandBase, digshapeArgs = {
        fill = "NA", --NA if unsupported by this command, "filled" or "hollow" if digshape supports it for this command
        digmode = "@", --'@': replace with current digmode.
        mode = "designating"--"designating" or "marking" or "toggling"
    } }

    --Make the self.activeCommand.digshapeArgs correct
    if self.digshapeCommands[commandBase].allowFilled then
            if currentFill ~= "NA"  then
                self.activeCommand.digshapeArgs.fill =currentFill

                else
                self.activeCommand.digshapeArgs.fill =  "hollow"
                end
        end

    self.activeCommand.digshapeArgs.digmode = self.digshapeCommands[commandBase].digMode
end

function DigshapeUI:parseCommand()
    --change a self.activeCommand.name into a full self.activeCommand, with complete digshapeString (not inc "digshape lua preview?")
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    stdout("MSG", "parsecommand:", self.activeCommand.name)

    --reset and clear out self.activeCommand
    self:clearCommand()

    --Setup the command arguments (to defaults), and build the digshapeString
    if self.activeCommand.args ~= nil then
        for argi = 1, #self.activeCommand.args do
            if self.activeCommand.args[argi].currentValue == nil then
                self.activeCommand.args[argi].currentValue = self.activeCommand.args[argi].default

                if type(self.activeCommand.args[argi].currentValue) == "table" then
                    self.activeCommand.args[argi].currentValue = self.activeCommand.args[argi].default.default
                    --todo: delete this once all the commands have full default={} stuff.
                end

            end

            if self.activeCommand.args[argi].guiOnlyArg ~= true then
                self.activeCommand.digshapeString = self.activeCommand.digshapeString .. " " .. tostring(self.activeCommand.args[argi].currentValue)
            else
              --  print("don't add this arg(" .. self.activeCommand.name .. ":" .. self.activeCommand.args[argi].name .. ") to digshape, internal use only.")

            end
        end
    end
    --print("fill", self.activeCommand.digshapeArgs.fill)
    if self.activeCommand.digshapeArgs.fill ~= "NA" then
        self.activeCommand.digshapeString = self.activeCommand.digshapeString .. " " .. self.activeCommand.digshapeArgs.fill
    end
    --print("dig", self.activeCommand.digshapeArgs.digmode)
    if self.activeCommand.digshapeArgs.digmode ~= nil then
        self.activeCommand.digshapeString = self.activeCommand.digshapeString .. " " .. self.activeCommand.digshapeArgs.digmode:gsub("@", self.activeDesgination)
    end

    self:rebuildDigshapeArgumentString()

    stdout("MSG", "Parsed command:", self.activeCommand.digshapeString)
end

function DigshapeUI:runCurrentCommand(preview)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
   -- print(">>>>", self.activeCommand.name, self.activeCommand.digshapeString)
    local command = ("digshape lua %s"):format(preview and "preview" or "")

    --Check for a BASECOMMAND argument, in case this is a command that needs to be run as another command. (eg. GUI ellipse runs both "ellipse bbox" and "ellipse 2axis")
    local nameCommand = self.activeCommand.name--self:parseCommand()
    local oldCommand = nil --if we swap commands during exicution, save here to revert.

    if self.digshapeCommands[nameCommand].args ~= nil then
        --check all args to see if one has a defaults table including 'commandBase'.
        --if it does, and nameCommand(currently trying to run) does not match commandBase(what this option wants to be run as), then we need to switch command to it.
        --printtable(self.digshapeCommands[nameCommand],i)
        local thisCommandIndex = nil
        local matchCommandIndex = nil
       -- printtable(self.digshapeCommands[nameCommand])
        for i = 1, #self.digshapeCommands[nameCommand].args do
            if type(self.digshapeCommands[nameCommand].args[i].default) == "table" and self.digshapeCommands[nameCommand].args[i].default.commandBase ~= nil then
                --get index of this arg in it's values list, and use that to select the right commandBase
                local swaptocommand = ""
                local valueToMatch = self.activeCommand.args[i].currentValue
                for ii, vv in ipairs(self.digshapeCommands[nameCommand].args[i].default.values) do
                    if self.digshapeCommands[nameCommand].args[i].default.commandBase[ii] == self.activeCommand.name then
                        thisCommandIndex = ii
                    end
                    if valueToMatch == vv then
                        --print("matchfound", vv, ii)
                        matchCommandIndex = ii
                    end
                end

                if thisCommandIndex ~= matchCommandIndex then
                    swaptocommand = self.digshapeCommands[nameCommand].args[i].default.commandBase[matchCommandIndex]
                    stdout(">>>", "Command swap: ", self.activeCommand.name, swaptocommand, thisCommandIndex, matchCommandIndex)
                    oldCommand = self.activeCommand
                    self:clearCommand()
                    self:setCommand(swaptocommand)
                    break
                end
            end
        end
    end

    self:rebuildDigshapeArgumentString()
    command = command .. " " .. self.activeCommand.digshapeString

    stdout("CMD", command, preview)
    if not verbose and not preview then
        local out, _ = command:gsub("lua ", "")
        stdout("OUT", out)
    end

    --check to make sure digshape will like the command, if not, don't bother calling and just return.
    local commandTests = self.digshapeCommands[nameCommand]
    if nameCommand == nil then
        stdout("WRN", "Current command will not exicute, skipping. 1")
        return
    end
    if commandTests.requireOrigin == true and self.origin == nil then
        stdout("WRN", "Current command will not exicute, skipping. 2")
        --try and recover by asking digshape
        self:runDigshapeCommand("digshape lua status")
        if commandTests.requireOrigin == true and self.origin == nil then
            self:runDigshapeCommand("digshape lua origin")
            --worms("Hard fail to debug. Function intentionally does not exist. Nondebug: just return nil.")
            return nil
        end
    end
    if commandTests.requireMajor == true and self.major == nil then
        stdout("WRN", "Current command will not exicute, skipping. 3")
        return nil
    end
    --if commandTests.requireZ==true and self.origin==nil then return nil end
    if commandTests.digMode ~= "@" and commandTests.digMod ~= self.activeDesgination then
        stdout("WRN", "Current command will not exicute, skipping. 4")
        return nil
    end

    self:runDigshapeCommand(command)
end

function DigshapeUI:runDigshapeCommand(command)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    --simple validity checks
    stdout("CMD", "RUNNING: '" .. command .. "'")
    if command == nil then
        stdout("ERR","nil command")
        return nil
    end

    local output = dfhack.run_command_silent(command)
    self.currentOutput = {}
    self.currentError = {}
    self.currentDig = {}
    self.origin = nil
    self.major = nil

    for line in output:gmatch("[^\r\n]+") do
        stdout("RBY", ">>" .. line)
        messageType = line:match("^([^:]+):")
        if messageType == "msg" then
            messageContents = line:match("^msg:(.*)$")
            table.insert(self.currentOutput, messageContents)
        elseif messageType == "err" then
            messageContents = line:match("^err:(.*)$")
            if line:match("Origin and target must be on the same z") then
                stdout("CMD", "-------------------------------RECURSIVELY RESETZ-----------------------")
                self:runDigshapeCommand("digshape lua resetz")
                self:runDigshapeCommand(command)
            else
                stdout("ERR",line)
            end
            table.insert(self.currentError, messageContents)
        elseif messageType == "dig" then
            --these are the designations from digshape
            digMode, x, y, z = line:match("^dig:([^:]+):([^:]+):([^:]+):([^:]+)")
            table.insert(self.currentDig, { digMode = digMode, x = tonumber(x), y = tonumber(y), z = tonumber(z), symbol = self.digButtons[digMode].symbol })
        elseif messageType == "pos" then
            posname, x, y, z = line:match("^pos:([^:]+):%(([^,]+),([^,]+),([^,]+)%)")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if posname == "origin" then
                self.origin = xyz2pos(x, y, z)
            elseif posname == "major" then
                self.major = xyz2pos(x, y, z)
                --elseif posname == "cursor" then
                --    self.cursor = xyz2pos(x, y, z)
            end
        elseif messageType == "ref" then
            messageContents = line:match("^ref:(.*)$")
            table.insert(self.currentOutput, messageContents)
            stdout("RBY", "ref:", messageContents)
        else
            stdout("WRN", "Digshape Unhandled Output:", line)
        end
    end

    if self.autosetZtoCurrent then
        local currentz = df.global.cursor.z
        for i = 1, #self.currentDig do
            self.currentDig[i].z = currentz
        end
        if self.origin ~= nil then
            self.origin.z = currentz
        end
        if self.major ~= nil then
            self.major.z = currentz
        end
    end

    stdout(">>>", "<<<<<<<< End call")
end

function DigshapeUI:previewCurrentCommand()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    self.runCurrentCommand(self, true)
end

function DigshapeUI:commitCurrentCommand()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    self.runCurrentCommand(self, false)
end

local function paintMapTile(dc, vp, cursor, pos, ...)
    if not same_xyz(cursor, pos) then
        local stile = vp:tileToScreen(pos)
        if stile.z == 0 then
            -- FIXME: reduce lag by increasing overlay
            dc:map(true):seek(stile.x, stile.y):char(...):map(false)
        end
    end
end

function DigshapeUI:buttonCallback_setOrigin()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    stdout("MSG", ">setorigin>")
    self:runDigshapeCommand("digshape lua origin")

    self:previewCurrentCommand()
end

function DigshapeUI:buttonCallback_swapOrigin()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    self:runDigshapeCommand("digshape lua swap")
    self:previewCurrentCommand()


end

function DigshapeUI:buttonCallback_setControlA()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    self:runDigshapeCommand("digshape lua major")
    self:previewCurrentCommand()
end

function DigshapeUI:buttonCallback_toggleFilled()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    if self.activeCommand.digshapeArgs.fill == "NA" then
        return
    end
    if self.activeCommand.digshapeArgs.fill == "filled" then
        self.activeCommand.digshapeArgs.fill = "hollow"
    else
        self.activeCommand.digshapeArgs.fill = "filled"
    end

    --since this is a callback we need to manually call these updates.
    self:updateMenuDisplay()
    self:previewCurrentCommand()
end

function DigshapeUI:buttonCallback_setCommand()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    --TODO: can maybe fix the stupid transparent edit box by making own class that supers all except changes the root gui:framedScreen.frame_background pen to not CLEAR_PEN....   or maybe editfield.on_char or on_change
    dialog.showInputPrompt("Set digshape command", "Enter a digshape command", COLOR_WHITE, "", function(result)
        self:changeCommandTo(result)
    end
    )
end

function DigshapeUI:updateDigMode(mode,set)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    set = set == "set" and "set" or "clear"
    --In the button list, insert a > and < before and after the currently selected item.

    local pitem = string.match(self.digButtons.order, "(.)" .. mode)
    local titem = "button_digmode_" .. mode

    if pitem == "_" then
        --we're outside the list of actual buttons, use the text [].
        pitem = "label_digmodeStart"
    else
        pitem = "button_digmode_" .. pitem
    end

    local kpen = self.pens.digMode.deselected
    local text = ""

    if set == "set" then
        local temp = self.pens.digMode.selected
        if mode == 'x' then
            temp = self.pens.digMode.delete
        elseif mode == 'M' then
            temp = self.pens.digMode.mark
        end
        kpen = temp
    end

    local doset
    doset = function(label, kpen, text,set)
        if text == "<" then
            self.subviews.digmodeMenu.text_ids[label].key_pen = kpen
        end
        self.subviews.digmodeMenu.text_ids[label].pen = kpen
        if set=="set" then
            self.subviews.digmodeMenu.text_ids[label].text = " "--text
        else
            self.subviews.digmodeMenu.text_ids[label].text =""
        end
    end

    doset(pitem, kpen, ">", set)--before
    doset(titem, kpen, "<", set)--thisitem
end

function DigshapeUI:buttonCallback_setDig(mode)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    local buttonCallback_setDig_labelhelper



    self:updateDigMode(self.activeDesgination, "clear")
    self:updateDigMode(mode, "set")
    self.subviews.digmodeMenu.text_ids["label_digmodeName"].text = self.digButtons[mode].text

    --do the update:
    self.activeDesgination = mode
    --regen digshape command
    self:parseCommand()
    self:previewCurrentCommand()
end

function DigshapeUI:getCurrentFill()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    local value = ""

    if self.digshapeCommands[self.activeCommand.name].allowFilled == false then
        value = "NA"
    else
        value = self.activeCommand.digshapeArgs.fill

    end
    return value
end

function DigshapeUI:buttonCallback_argAdjust(argNum, argDir, argMod)
    --TODO: make these curried as ARG#, INC/DEC={"+", "-"}, MODIFIER?S?
    -- --(TODO: argMod::  SHIFT-inc: *2, CTRL-inc: *5, ALT-inc: /10; modifiers stack. )
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    local tempDir = 1
    if argDir == "-" then
        tempDir = tempDir * -1
    end
    local tempMod = 1

    local arg = self.activeCommand.args[argNum]
    stdout(">>>", "argadj---------------------", argNum, argDir, argMod)
    printtable(self.activeCommand, "Arg Adj")
    if arg == nil then
        stdout("ERR","NIL ARG", argNum, argDir, argMod)
        return
    end
    if argDir == "reset" then
        stdout("MSG", "Reset all args to default.")
        self:setCommand(self.activeCommand.name)
        return
    end

    if type(arg.default) == "table" then
        tempMod = tempMod * arg.default.inc
    end
    tempMod = tempMod * (argMod)

    stdout("MSG", "argAdj: " .. argNum .. ":: " .. tempDir .. "," .. tempMod)
    local newvalue

    if type(arg.currentValue) == "boolean" then
        newvalue = not arg.currentValue
    elseif type(arg.default) == "table" and arg.default.values ~= nil then
        local index = 1
        local found = false
        while not found do
            for currentindex = 1, #arg.default.values do
                if arg.default.values[currentindex] == arg.currentValue then
                    index = currentindex
                    found = true
                    break
                end
                --the while loop lets us loop around the back of the list. TODO: fix this dirty hack.
            end
            index = index + 1
            if index > #arg.default.values then
                index = 1
            end
            newvalue = arg.default.values[index]
        end
    else
        newvalue = arg.currentValue + (1 * tempDir * tempMod)
        if type(arg.default) == "table" then
            if arg.default.mod ~= nil then
                newvalue = newvalue % arg.default.mod
            elseif newvalue < arg.default.min then
                newvalue = arg.default.min
            elseif newvalue > arg.default.max then
                newvalue = arg.default.max
            end
        end
    end
    arg.currentValue = newvalue
    stdout("MSG", "ArgAdj:" .. arg.name .. "=" .. tostring(arg.currentValue))
    printtable(self.activeCommand, "Arg Adj2")
    self:updateMenuDisplay()
    self:previewCurrentCommand()
end

--
--function DigshapeUI:buttonCallback_()
--
--end

function DigshapeUI:buttonCallback_undo()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    dfhack.run_command("digshape undo")
end

function DigshapeUI:buttonCallback_commit()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    self:commitCurrentCommand()
end

--function DigshapeUI:buttonCallback_setCommand()
--
--end



function DigshapeUI:buttonCallback_recenterView()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    stdout("MSG", "recenter view:", self.origin)
    dfhack.gui.revealInDwarfmodeMap(self.origin)
    --todo: move cursor back on screen too... in it's relative position?
end

function DigshapeUI:buttonCallback_showHelpPopup()
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)

end
--
--function DigshapeUI:buttonCallback_()
--
--end
--function DigshapeUI:buttonCallback_()
--
--end
















function DigshapeUI:renderOverlay()
    --stdout("CAL",debug.getinfo(1,'n').name or "@ line "..debug.getinfo(1,'S').linedefined)
    --todo: consider --https://docs.dfhack.org/en/stable/docs/Lua%20API.html#penarray-class for speedup
    local vp = self:getViewport()
    local dc = gui.Painter.new(self.df_layout.map)
    local visible = gui.blink_visible(500)

    local cursorX, cursorY, cursorZ = df.global.cursor.x, df.global.cursor.y, df.global.cursor.z
    if lastX ~= cursorX or lastY ~= cursorY or lastZ ~= cursorZ then
        lastX, lastY, lastZ = cursorX, cursorY, cursorZ
        --we have moved cursor, so update the state of the preview
        self:previewCurrentCommand()
    end

    for _, dig in ipairs(self.currentDig) do
        paintMapTile(dc, vp, df.global.cursor, xyz2pos(dig.x, dig.y, dig.z), dig.symbol, self.activeDesgination == 'x' and self.pens['clear'] or self.pens['designation'])
    end

    if self.digshapeCommands[self.activeCommand.name].requireOrigin then
        if self.origin then
            paintMapTile(dc, vp, df.global.cursor, self.origin, '+', self.pens['origin'])
        end
    end
    if self.activeCommand.name ~= nil then
        if self.major then
            if self.digshapeCommands[self.activeCommand.name].requireMajor then
                paintMapTile(dc, vp, df.global.cursor, self.major, 'a', self.pens['ctrl_A'])

            end
        end

    end


end

function DigshapeUI:onRenderBody(dc)
    --stdout("CAL",debug.getinfo(1,'n').name or "@ line "..debug.getinfo(1,'S').linedefined)
    if self.changeCommandToCommand ~= nil then
        self:setCommand(self.changeCommandToCommand)
        self.changeCommandToCommand = nil
    end
    self:renderOverlay()

    dc:clear():seek(1, 1):pen(COLOR_WHITE):string("Digshape - " .. self.state)


end

function DigshapeUI:onInput(keys)
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    stdout(">>>", "===========ON INPUT===========")

    --TODO: deal with multi-key presses, because keys is an array of individuals.

    if df.global.cursor.x == -30000 then
        local vp = self:getViewport()
        df.global.cursor = xyz2pos(math.floor((vp.x1 + math.abs((vp.x2 - vp.x1)) / 2) + .5), math.floor((vp.y1 + math.abs((vp.y2 - vp.y1) / 2)) + .5), vp.z)
        return
    end

    for k, v in pairs(keys) do
        if k:match("^A_MOVE_") then
            self.refresh = 1
        end
    end

    DigshapeUI.super.onInput(self, keys) --call super so subviews (eg. the widges.Labels) can capture keypresses too.

    if keys.LEAVESCREEN then
        self:dismiss()
    elseif self:propagateMoveKeys(keys) then
        return
    end
    stdout("CAL", debug.getinfo(1, 'n').name or "@ line " .. debug.getinfo(1, 'S').linedefined)
    --self:updateMenuDisplay()
    --self:previewCurrentCommand()
end

if not (dfhack.gui.getCurFocus():match("^dwarfmode/Default") or dfhack.gui.getCurFocus():match("^dwarfmode/Designate") or dfhack.gui.getCurFocus():match("^dwarfmode/LookAround")) then
    qerror("This screen requires the main dwarfmode view or the designation screen")
end

local list = DigshapeUI { state = "mark", blink = false, cull = true }
list:show()