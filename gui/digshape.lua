--gui front-end for digshape.rb, a geometric designations generating tool
--[====[

gui/digshape
===========
gui front-end for digshape.rb, a geometric designations generating tool
]====]

verbose = false --TODO: move these down later to be arguments
--dfhack.screen.invalidate() --force an immediate redraw.

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

stdout = function(...)
end--silently discard

if verbose then
    --atm verbose must be set manually, see line2 of this script.
    dfhack.console.clear()
    stdout = function(msgtype, ...)
        --A stupid pretty console print command.
        local prefix = ""
        if type(msgtype) == "string" then
            _, _, temp = string.find(msgtype, "^(...)$")
            if temp == "ERR" or temp == "MSG" or temp == "WRN" or temp == "OUT" or temp == "CMD" or temp == "RBY" then
                --output channels: MSG/WRN/ERR: information, OUT: results, RBY: digshape output passed through.
                if temp == "IGNORE" or temp == "ALSOIGNORE" or temp == "RBlY" then
                    return --don't print
                end

                if verbose == false and temp ~= "ERR" then
                    return --only print errors when not verbose
                end

                prefix = " DS: " .. msgtype .. ": "
                msgtype = ""
            else
                prefix = " DS: "
            end

        end
        print(prefix, msgtype, ...)
    end
    --TOOD: fancy! https://www.lua.org/pil/6.html
else
    -- print=nil --suckers, don't print anything.
end

--stdout("gui/Digshape verbose output"," ".."!")
--stdout("ERR", "gui/Digshape verbose output"," ".."!")
--stdout("ERR", "A", "B", "C","D".."D")
--stdout("A", "B", "C","D".."D")

DigshapeUI = defclass(DigshapeUI, guidm.MenuOverlay)

DigshapeUI.ATTRS {
    state = "preview",
    activeDesgination = 'd',
    currentCommand = 'spiral', --TODO: replace this with self.digshapeCommands.current
    parsedCommand = DEFAULT_NIL, --TODO: move this to self.digshapeCommands.current.parsedCommand

    currentOutput = {},
    currentError = {},
    currentDig = {},
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

        origin = dfhack.pen.make({ ch = '+', fg = COLOR_CYAN, bg = COLOR_LIGHTGREEN }),
        cursor = dfhack.pen.make({ ch = 'X', fg = COLOR_CYAN, bg = COLOR_BLACK }),
        ctrl_A = dfhack.pen.make({ ch = 'a', fg = COLOR_CYAN, bg = COLOR_LIGHTCYAN }),
        designation = dfhack.pen.make({ fg = COLOR_BROWN, bg = COLOR_YELLOW }),
        mark = dfhack.pen.make({ fg = COLOR_YELLOW, bg = COLOR_LIGHTCYAN }),
        clear = dfhack.pen.make({ fg = COLOR_BROWN, bg = COLOR_RED }),
        digMode = {
            selected = dfhack.pen.make({ fg = COLOR_BLACK, bg = COLOR_LIGHTGREEN }),
            deselected = dfhack.pen.make({ fg = COLOR_LIGHTGREEN, bg = COLOR_BLACK }),
            delete = dfhack.pen.make({ fg = COLOR_BLACK, bg = COLOR_LIGHTRED }),
            mark = dfhack.pen.make({ fg = COLOR_BLACK, bg = COLOR_LIGHTCYAN }),
        },
    },

    --Designation mode variables (to be saved between commands)
    -- designateDigMode = {}, --what is the UI selected digMode?
    designateMarking = false, --are we designating "marking" rather than standard?
    designateFilled = false, --filled or hollow? (will be ignored if current command does not allow/use it)



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


        current = { command = "circle", args = {} }, --current stores the currently active command, and it's arguments and values.

        --COMMAND={requireOrigin = false, requireMajor = false, requireZ = false, allowFilled = false, args = {name="",required=true,default=nil,type="",desc=""}, runSilent = true, digMode = nil, desc = "Set the origin"},

        origin = { requireOrigin = false, requireMajor = false, requireZ = false, allowFilled = false, args = nil, runSilent = true, digMode = nil, desc = "Set the origin" },
        controla = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Set the first control point (A, or 'major')" },
        swap = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Swap the origin and cursor" },

        circle = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Draw a circle" },

        line = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = nil, runSilent = false, digMode = "@", desc = "Draw a line" },

        ellipse = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = {}, runSilent = false, digMode = "@", desc = "Draw a ellipse" },

        polygon = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "sides", required = true, default = 3, type = "int", desc = "Number of sides of the polygon" }, { name = "vertex", required = true, default = false, type = "bool", desc = "Is the cursor on a vertex, or the midpoint of a side?" }, }, runSilent = false, digMode = "@", desc = "Draw a polygon" },

        star = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "points", required = true, default = 5, type = "int", desc = "Number of points of the star" }, { name = "skip", required = true, default = 2, type = "int", desc = "How many to skip when connecting...?" }, }, runSilent = false, digMode = "@", desc = "Draw a star" },

        spiral = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = false, args = { { name = "coils", required = true, default = 2, type = "int", desc = "Number of turns the spiral makes." }, { name = "skip", required = true, default = 1, type = "int", desc = "Draw every # points along spiral." }, { name = "rotate", required = true, default = { default = 0, min = -360, max = 360, inc = 15, type = "int" }, type = "int", desc = "Rotate the spiral, 0-360." }, }, runSilent = false, digMode = "@", desc = "Draw a spiral" },

        flood = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = { { name = "max", required = false, default = 10000, type = "int", desc = "Maximum number of tiles filled before aborting. Larger numbers just take longer to complete." }, { name = "diagonals", required = false, default = false, type = "bool", desc = "Should the flood escape through corners?" }, }, runSilent = false, digMode = "@", desc = "Floodfill current designation" },

        resetz = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false, digMode = "@", desc = "Move all control points to current z level" },
        radial = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = { { name = "ways", required = true, default = 3, type = "int", desc = "Number of radially symetrical points to draw." }, }, runSilent = false, digMode = "@", "Draw points with radial symmetry around origin" }, --todo: code this
        curve = { requireOrigin = true, requireMajor = true, requireZ = true, allowFilled = false, args = { { name = "Sharpness", required = true, default = { default = 1.5, min = 0, max = 100, inc = 0.1, type = "float" }, type = "float", desc = "How strongly the curve is pulled towards the cursor" } }, runSilent = false, digMode = "@", desc = "Draw a curve (bezier) from origin to major pulled towards cursor" }, --todo: allow filled. Also draw line, then fill shape
        --{ default = 1.5, min = 0, max = 100, inc = 0.1, type = "float" }
        --arc = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = nil, runSilent = false,digMode="@",desc="Draw an arc from origin to major passing through cursor." },
        downstair = { requireOrigin = true, requireMajor = false, requireZ = true, allowFilled = true, args = { { name = "depth", required = true, default = 1, type = "int", desc = "Number of z levels down to designate." }, { name = "start", required = true, default = true, type = "bool", desc = "Should the starting level be updown [false] or down [true]" }, }, runSilent = false, digMode = "@", desc = "Designate a 3x3 block of updown stairs, corners and center only" },
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

                { key = "CUSTOM_A", text = "Set major", key_sep = ": ",
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
                { text = "[ digshape command ]", gap = 2, pen = COLOR_YELLOW, id = "label_digshapeCommand" }, NEWLINE,
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
    --todo: make this a skippable option based on argument. Other values might include "here", "last", "coords"
    if self.origin == nil then
        self:runDigshapeCommand("digshape lua origin")
    end

    --assume we're always working on the current z level, todo: make this an option based on argument
    self.autosetZtoCurrent = true

    --display the current command preview
    self:buttonCallback_setDig(self.activeDesgination)
    self:setCommand(self.currentCommand)
    self:previewCurrentCommand()
    --dfhack.gui.revealInDwarfmodeMap(self.origin)
end

function DigshapeUI:onDestroy()
    df.global.ui.main.mode = self.saved_mode
end

function DigshapeUI:toggleSubViewVis(viewID, setActiveByVis)
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


function DigshapeUI:parseCommand()
    stdout("MSG", "parsecommand:", self.currentCommand)
    --if self.parsedCommand == nil then
    local commandBase = self.currentCommand:lower():match("^%a+")
    self.parsedCommand = commandBase
    self.digshapeCommands.current = { command = commandBase, args = {} }

    local args = { commandargs = self.digshapeCommands[commandBase].args, --copyall() the command specific arguments (eg "chords" for digshape spiral). We use copyall to get a copy so it remains unchanged.
                   genericargs = {
                       fill = "NA", --NA if unsupported by this command, "filled" or "hollow" if digshape supports it for this command
                       digmode = "@", --'@': replace with current digmode.
                       mode = "designating"--"designating" or "marking" or "toggling"
                   } }
    if self.digshapeCommands[commandBase].allowFilled then
        args.genericargs.fill = self.designateFilled and "filled" or "hollow"
    end
    -- if self.digshapeCommands[commandBase].digMode ~= nil then
    args.genericargs.digmode = self.digshapeCommands[commandBase].digMode
    -- end
    --print("1>")    for k,v in pairs(args.commandargs) do print("   1>"..k..":"..v) end    for k,v in pairs(args.genericargs) do print("   2>"..k..":"..v) end


    --local buildCommand = {
    --    --for each digshape command, setup it's arg string, and TODO: check that it's conditions are met.
    --    circle = function(self, args)
    --        local temp = self.digshapeCommands[self.digshapeCommands.current.command].allowFilled and self.designateFilled and "filled" or "hollow"
    --        args.genericargs.fill = temp
    --    end,
    --    origin = function(self, args)
    --    end,
    --}
    --buildCommand[commandBase](self, args)
    --print("2>")    for k,v in pairs(args.commandargs) do print("   1>"..k..":"..v) end    for k,v in pairs(args.genericargs) do print("   2>"..k..":"..v) end
    if args.commandargs ~= nil then
        --self.digshapeCommands[self.digshapeCommands.current.command].args ~= nil then
        --print(">", self.digshapeCommands.current.command)
        for argi = 1, #args.commandargs do
            --for k, _ in pairs(self.digshapeCommands[self.digshapeCommands.current.command].args) do
           -- print("->", argi)
            if args.commandargs[argi].currentValue == nil then
                args.commandargs[argi].currentValue = args.commandargs[argi].default
            end
            if type(args.commandargs[argi].currentValue) == "table" then
                args.commandargs[argi].currentValue = args.commandargs[argi].default.default
                --todo: delete this once all the commands have full default={} stuff.
            end

            self.subviews.digshapeMenu.text_ids["label_arg" .. argi .. "value"].text = tostring(args.commandargs[argi].currentValue)
            self.subviews.digshapeMenu.text_ids["label_arg" .. argi .. "name"].text = args.commandargs[argi].name
            self.parsedCommand = self.parsedCommand .. " " .. tostring(args.commandargs[argi].currentValue)
        end
    end
    if args.genericargs.fill ~= "NA" then
        self.parsedCommand = self.parsedCommand .. " " .. args.genericargs.fill
    end
    if args.genericargs.digmode ~= nil then
        self.parsedCommand = self.parsedCommand .. " " .. args.genericargs.digmode:gsub("@", self.activeDesgination)

    end

    self.digshapeCommands.current.args = args
    --  end

    self.subviews.digshapeMenu.text_ids.label_digshapeCommand.text = "[ " .. self.parsedCommand .. " ]"

    return commandBase
end

function DigshapeUI:runCurrentCommand(preview)
    local command = ("digshape lua %s"):format(preview and "preview" or "")
    local baseCommand = self:parseCommand()
    command = command .. " " .. self.parsedCommand

    stdout("CMD", command, preview)

    --check to make sure digshape will like the command, if not, don't bother calling and just return.
    local commandTests = self.digshapeCommands[baseCommand]
    if baseCommand == nil then
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
    --simple validity checks
    stdout("CMD", "RUN:", command)
    if command == nil then
        print("nil command")
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
            --  stdout("ERR", "Digshape Unhandled Output:", line)
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
end

function DigshapeUI:previewCurrentCommand()
    self.runCurrentCommand(self, true)
end

function DigshapeUI:commitCurrentCommand()
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
    stdout("MSG", ">setorigin>")
    self:runDigshapeCommand("digshape lua origin")

    self:previewCurrentCommand()
end

function DigshapeUI:buttonCallback_swapOrigin()
    self:runDigshapeCommand("digshape lua swap")
    self:previewCurrentCommand()


end

function DigshapeUI:buttonCallback_setControlA()
    self:runDigshapeCommand("digshape lua major")
    self:previewCurrentCommand()
end

function DigshapeUI:buttonCallback_toggleFilled()
    self.designateFilled = not self.designateFilled
    self.parsedCommand = nil
    self:previewCurrentCommand()

    self.subviews.controlPointsMenu.text_ids.button_toggleFill.text = "Toggle fill: " .. self:getCurrentFill()
end

function DigshapeUI:setCommand(newCommand)
    local showArgs
    showArgs = function(self, command)
        -- stdout("MSG", ">showargs> " .. command)
        -- print(self.currentCommand)
        local args = self.digshapeCommands[command].args
        local ids = { "button_arg#dec", "button_arg#inc", "label_arg#name", "label_arg#sepA", "label_arg#sepB", "label_arg#sepC", "label_arg#value"}--, "button_resetArgs" }--,"label_arg#desc"}

        local nargs = 0
        if args ~= nil then
            for i, v in ipairs(args) do
                for k = 1, #ids do
                    local index = string.gsub(ids[k], "#", i)
                    -- print("vis", i, k, index)
                    local temp = self.subviews.digshapeMenu.text_ids[index]
                    temp.disabled = false
                end
                nargs = nargs + 1
            end
        end

        if nargs < 3 then
            for i = nargs + 1, 3 do
                for k = 1, #ids do
                    local index = string.gsub(ids[k], "#", i)
                    --  print("hide", i, k, index)
                    local temp = self.subviews.digshapeMenu.text_ids[string.gsub(ids[k], "#", i)]
                    temp.dpen = CLEAR_PEN
                    temp.disabled = true
                end
                self.subviews.digshapeMenu.text_ids["label_arg" .. i .. "name"].text = "--------"
                self.subviews.digshapeMenu.text_ids["label_arg" .. i .. "value"].text = "-"
            end

        end
    end
    self.currentCommand = newCommand
    self.parsedCommand = nil
    local command = self:parseCommand()
    self:runDigshapeCommand("digshape lua status")
    showArgs(self, command)--showargs first so that preview updates their values.
    self:previewCurrentCommand()

end

function DigshapeUI:buttonCallback_setCommand()
    --TODO: can maybe fix the stupid transparent edit box by making own class that supers all except changes the root gui:framedScreen.frame_background pen to not CLEAR_PEN....   or maybe editfield.on_char or on_change


    dialog.showInputPrompt("Set digshape command", "Enter a digshape command", COLOR_WHITE, "", function(result)
        self:setCommand(result)
    end
    )


end

function DigshapeUI:buttonCallback_setDig(mode)
    local buttonCallback_setDig_labelhelper
    buttonCallback_setDig_labelhelper = function(mode, set)
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
        doset = function(label, kpen, text)
            --for k, v in pairs(self.subviews.digmodeMenu.text_ids) do
            --    print(k, v)
            --end

            if text == "<" then
                self.subviews.digmodeMenu.text_ids[label].key_pen = kpen
            end
            self.subviews.digmodeMenu.text_ids[label].pen = kpen
            self.subviews.digmodeMenu.text_ids[label].text = " "--text
        end

        doset(pitem, kpen, ">")--before
        doset(titem, kpen, "<")--thisitem
    end

    buttonCallback_setDig_labelhelper(self.activeDesgination, "clear")
    buttonCallback_setDig_labelhelper(mode, "set")
    self.subviews.digmodeMenu.text_ids["label_digmodeName"].text = self.digButtons[mode].text

    --do the update:
    self.activeDesgination = mode
    self.parsedCommand = nil --regen digshape command
    self:parseCommand()
    self:previewCurrentCommand()
end

function DigshapeUI:getCurrentFill()
    local value = ""

    if self.digshapeCommands[self.digshapeCommands.current.command].allowFilled == false then
        value = "NA"
    elseif self.designateFilled then
        value = "Filled"
    else
        value = "Hollow"
    end
    return value
end

function DigshapeUI:buttonCallback_argAdjust(argNum, argDir, argMod)
    --TODO: make these curried as ARG#, INC/DEC={"+", "-"}, MODIFIER?S?
    -- --(TODO: argMod::  SHIFT-inc: *2, CTRL-inc: *5, ALT-inc: /10; modifiers stack. )

    local tempDir = 1
    if argDir == "-" then
        tempDir = tempDir * -1
    end
    local tempMod = 1

    local arg = self.digshapeCommands.current.args.commandargs[argNum]
    if argDir == "reset" then
        stdout("MSG","Reset all args to default.")
        self:setCommand(self.digshapeCommands.current.command)
        return
    end

    if type(arg.default) == "table" then
        tempMod = tempMod * arg.default.inc
    end
    tempMod = tempMod * (argMod)

    stdout("argAdj: ", argNum, ") ", tempDir, tempMod)

    if type(arg.currentValue) == "boolean" then
        arg.currentValue = not arg.currentValue
    else
        local newval = self.digshapeCommands.current.args.commandargs[argNum].currentValue + (1 * tempDir * tempMod)
        if type(arg.default) == "table" then
            if newval < arg.default.min then
                newval = arg.default.min
            elseif newval > arg.default.max then
                newval = arg.default.max
            end
        end
        self.digshapeCommands.current.args.commandargs[argNum].currentValue = newval
    end
    self:previewCurrentCommand()
end

--
--function DigshapeUI:buttonCallback_()
--
--end

function DigshapeUI:buttonCallback_undo()
    dfhack.run_command("digshape undo")
end

function DigshapeUI:buttonCallback_commit()
    self:commitCurrentCommand()
end

--function DigshapeUI:buttonCallback_setCommand()
--
--end



function DigshapeUI:buttonCallback_recenterView()
    stdout("MSG", "recenter view:", self.origin)
    dfhack.gui.revealInDwarfmodeMap(self.origin)
end
--function DigshapeUI:buttonCallback_()
--
--end
--
--function DigshapeUI:buttonCallback_()
--
--end
--function DigshapeUI:buttonCallback_()
--
--end
















function DigshapeUI:renderOverlay()
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

    if self.origin then
        paintMapTile(dc, vp, df.global.cursor, self.origin, '+', self.pens['origin'])
    end
    if self.digshapeCommands.current.command~=nil then
        if self.major then
            if self.digshapeCommands[self.digshapeCommands.current.command].requireMajor then
                paintMapTile(dc, vp, df.global.cursor, self.major, 'a', self.pens['ctrl_A'])

            end
        end

    end


end

function DigshapeUI:onRenderBody(dc)
    self:renderOverlay()

    dc:clear():seek(1, 1):pen(COLOR_WHITE):string("Digshape - " .. self.state)

end

function DigshapeUI:onInput(keys)

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
end

if not (dfhack.gui.getCurFocus():match("^dwarfmode/Default") or dfhack.gui.getCurFocus():match("^dwarfmode/Designate") or dfhack.gui.getCurFocus():match("^dwarfmode/LookAround")) then
    qerror("This screen requires the main dwarfmode view or the designation screen")
end

local list = DigshapeUI { state = "mark", blink = false, cull = true }
list:show()