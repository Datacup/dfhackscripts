--designating tool

--[====[

gui/digshape
===========
gui front-end for digshape.rb

]====]

local utils = require "utils"
local gui = require "gui"
local guidm = require "gui.dwarfmode"
local dialog = require "gui.dialogs"

DigshapeUI = defclass(DigshapeUI, guidm.MenuOverlay)

DigshapeUI.ATTRS {
    state = "preview",
    activeDesgination = 'd',
    currentCommand = 'circle hollow @',
    currentOutput = {},
    currentError = {},
    currentDig = {},
    -- default properties for self here

    --Preview mode variables
    blink = false, --should the preview blink?
    blinkrate = { 3, 750, 350, 125 }, --how fast do we blink. blinkrate[1] is the index of the chosen rate.
    pens={
        --{key, symbol character code, fgcolor, bgcolor}
        ['origin']=dfhack.pen.make({ch='+',fg=COLOR_CYAN,bg=COLOR_LIGHTGREEN}),
        ['cursor']=dfhack.pen.make({ch='X',fg=COLOR_CYAN,bg=COLOR_LIGHTGREEN}),
        ['major']=dfhack.pen.make({ch='a',fg=COLOR_CYAN,bg=COLOR_LIGHTGREEN}),
        ['designation']=dfhack.pen.make({fg=COLOR_BROWN,bg=COLOR_YELLOW}),
        ['mark']=dfhack.pen.make({fg=COLOR_YELLOW,bg=COLOR_LIGHTCYAN}),
        ['clear']=dfhack.pen.make({fg=COLOR_BROWN,bg=COLOR_RED})
    },

    --Designation mode variables
    designateMarking = false, --are we designating "marking" rather than standard?


    --Mouse variables
    mouse = true,
    mousebuttons={'commit','origin','major'},
    dragging = false,
    lastMouse = xyz2pos(0, 0, 0),
    lerp = true, --lerp is laggy because it repeatedly inefficiently accesses memory; it would be faster if we cached some but thats above my paygrade ;)
    customOffset = { x = 0, y = 0 },
}


local digButtons={
    {key='d', symbol=" ", text="Mine"},
    {key='i', symbol="X", text="U/D Stair"},
    {key='h', symbol="_", text="Channel"},
    {key='r', symbol=30, text="Up Ramp"},
    {key='j', symbol=">", text="Down Stair"},
    {key='u', symbol="<", text="Up Stair"},
    {key='x', symbol=" ", text="Remove Designation"},
    {key='M', symbol=" ", text="Toggle Dig/Mark"}
}

local digModeToButton = {}
for _, data in pairs(digButtons) do
    data.keybind = ("CUSTOM_".. (string.match(data.key,"%u") ~=nil and "SHIFT_" or "") .."%s"):format(data.key:upper())
    digModeToButton[data.key] = data
    print("~")
end

local buttons = {
    --key: the key that will be bound to callback. For non-button entries (eg blank lines), set key="NOTKEY" to skip the keybinding.
    --text: the label for the keybind
    --prelabel: a menu rendering function exicuted before displaying the keybinding, use to newline or set color, etc
    --postlabel: as prelabel, but after the keybinding label is printed.
    --callback: the function called by this button
    {key="p", text="Set digshape command", postlabel=function(self, dc)
        dc:newline(1):advance(3):pen(COLOR_YELLOW):string("[ "..self.currentCommand.." ]")
    end, callback=function(self)
        dialog.showInputPrompt("Set digshape command", "Enter a digshape command", COLOR_WHITE, self.currentCommand, function(result)
            self.currentCommand=result
            self:runCurrentCommand(true)
        end)
    end},
    {key="o", text="Set origin",prelabel=function(self,dc)dc:newline(1) if self.origin ~=nil then dc:pen(COLOR_LIGHTGREEN) else dc:pen(COLOR_LIGHTRED)  end end, callback=function(self)
        dfhack.run_command_silent("digshape lua origin")
        self:runCurrentCommand(true)
    end},
    {key="s", text="Swap origin/cursor", prelabel=function(self,dc)dc:newline(1):advance(2) if self.origin ~=nil then dc:pen(COLOR_LIGHTGREEN) else dc:pen(COLOR_LIGHTRED)  end end, callback=function(self)
        dfhack.run_command_silent("digshape lua swap")
        self:runCurrentCommand(true)
    end},

    {key="a", text="Set major", callback=function(self)
        dfhack.run_command_silent("digshape lua major")
        self:runCurrentCommand(true)
    end},
    {key="NOTKEY",prelabel=function(self,dc)dc:newline(2) end},
    {key="SELECT", keybind="SELECT", text="Execute command", callback=function(self)
        self:runCurrentCommand(false)
    end},
    {key="z", text="Undo digshape command", callback=function(self)
        dfhack.run_command("digshape undo")
    end}
}
for _, data in pairs(buttons) do
    data.keybind = data.keybind or ("CUSTOM_%s"):format(data.key:upper())
end

local lastX = df.global.cursor.x
local lastY = df.global.cursor.y
local lastZ = df.global.cursor.z

function DigshapeUI:runCurrentCommand(preview)
    local command = ("digshape lua %s%s"):format(preview and "preview " or "", self.currentCommand):gsub("@", self.activeDesgination)
    print(("command='%s'"):format(command))
    local output = dfhack.run_command_silent(command)
    self.currentOutput = {}
    self.currentError = {}
    self.currentDig = {}
    self.origin = nil
    self.major = nil
    print("output=", output)
    for line in output:gmatch("[^\r\n]+") do
        messageType = line:match("^([^:]+):")
        if messageType == "msg" then
            messageContents = line:match("^msg:(.*)$")
            table.insert(self.currentOutput, messageContents)
        elseif messageType == "err" then
            messageContents = line:match("^err:(.*)$")
            table.insert(self.currentError, messageContents)
        elseif messageType == "dig" then
            digMode, x, y, z = line:match("^dig:([^:]+):([^:]+):([^:]+):([^:]+)")
            table.insert(self.currentDig, {digMode=digMode, x=tonumber(x), y=tonumber(y), z=tonumber(z), symbol=digModeToButton[digMode].symbol})
        elseif messageType == "pos" then
            posname, x, y, z = line:match("^pos:([^:]+):%(([^,]+),([^,]+),([^,]+)%)")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if posname == "origin" then
                self.origin = xyz2pos(x, y, z)
            elseif posname == "major" then
                self.major = xyz2pos(x, y, z)
            end
                
        else
            print("unhandled output:", line)
        end
    end
end

function DigshapeUI:init()
    self.saved_mode = df.global.ui.main.mode
    df.global.ui.main.mode=df.ui_sidebar_mode.LookAround
    self:runCurrentCommand(true)
end

function DigshapeUI:onDestroy()
    df.global.ui.main.mode = self.saved_mode
end

local function paintMapTile(dc, vp, cursor, pos, ...)
    if not same_xyz(cursor, pos) then
        local stile = vp:tileToScreen(pos)
        if stile.z == 0 then -- FIXME: reduce lag by increasing overlay
            dc:map(true):seek(stile.x,stile.y):char(...):map(false)
        end
    end
end


function DigshapeUI:renderOverlay()
    local vp=self:getViewport()
    local dc = gui.Painter.new(self.df_layout.map)
    local visible = gui.blink_visible(500)

    local cursorX, cursorY, cursorZ = df.global.cursor.x, df.global.cursor.y, df.global.cursor.z
    if lastX ~= cursorX or lastY ~= cursorY or lastZ ~= cursorZ  then
        lastX, lastY, lastZ = cursorX, cursorY, cursorZ
        self:runCurrentCommand(true)
    end

    for _, dig in ipairs(self.currentDig) do
        paintMapTile(dc, vp, df.global.cursor, xyz2pos(dig.x, dig.y, dig.z), dig.symbol, self.activeDesgination=='x' and self.pens['clear'] or self.pens['designation'])
    end

    if self.origin then
        paintMapTile(dc, vp, df.global.cursor, self.origin, '+', self.pens['origin'])
    end
    if self.major then
        paintMapTile(dc, vp, df.global.cursor, self.major, '+', self.pens['major'])
    end
    
        
end

function DigshapeUI:onRenderBody(dc)
    self:renderOverlay()

    dc:clear():seek(1, 1):pen(COLOR_WHITE):string("Digshape - " .. self.state--:gsub("^%a", function(x)
     --   return x:upper()
   -- end)
    )
    dc:seek(1,3)

    if true or self.state=="preview" then
        for _, data in pairs(digButtons) do
            builder = dc:newline(1):key_string(data.keybind, data.text, self.activeDesgination==data.key and COLOR_WHITE or COLOR_GREY)
           -- if data.key=='x' then
           --     builder:newline(1)
           -- end
        end

        dc:newline(2)

        for _, data in pairs(buttons) do
            if data.prelabel ~= nil then
                data.prelabel(self,dc)
            else
                dc:newline(1):pen(COLOR_GREY)
            end
            if data.key~="NOTKEY" then
                builder = dc:key_string(data.keybind, data.text)
            end
            if data.postlabel ~= nil then
                data.postlabel(self,dc)
            end
            --if data.key=='m' then
            --builder:newline(1)
            --end
            end

        
        --[[ dc:key_string("CUSTOM_S", "Set Brush",COLOR_GREY)
        dc:newline():newline(1)
        dc:key_string("CUSTOM_H", "Flip Horizontal",COLOR_GREY):newline(1)
        dc:key_string("CUSTOM_V", "Flip Vertical",COLOR_GREY):newline(1)
        dc:key_string("CUSTOM_R", "Rotate 90",COLOR_GREY):newline(1)
        dc:key_string("CUSTOM_T", "Rotate -90",COLOR_GREY):newline(1)
        dc:key_string("CUSTOM_G", "Cycle Corner",COLOR_GREY):newline(1)
        dc:key_string("CUSTOM_I", "Invert",COLOR_GREY):newline(1)
        dc:key_string("CUSTOM_C", "Convert to...",COLOR_GREY):newline(1)
        dc:newline(1)
        dc:key_string("CUSTOM_E", (self.option=="erase" and "Erasing" or "Erase"),self.option=="erase" and COLOR_RED or COLOR_GREY):newline(1) --make red
        dc:key_string("CUSTOM_X", (self.option=="construction" and "Removing" or "Remove").." Constructions",self.option=="construction" and COLOR_GREEN or COLOR_GREY):newline(1) --make red
        dc:newline():newline(1)
        dc:key_string("CUSTOM_B", "Blink Brush",self.blink and COLOR_WHITE or COLOR_GREY):newline(1)
        dc:newline() ]]
    end

    dc:newline():newline(1):key_string("LEAVESCREEN", "Back")
end


function DigshapeUI:onInput(keys)
    if df.global.cursor.x==-30000 then
        local vp=self:getViewport()
        df.global.cursor=xyz2pos(math.floor((vp.x1+math.abs((vp.x2-vp.x1))/2)+.5),math.floor((vp.y1+math.abs((vp.y2-vp.y1)/2))+.5), vp.z)
        return
    end
    for k,v in pairs(keys) do
        if k:match("^A_MOVE_") then
            self.refresh = 1
        end
    end
    if true or self.state=="preview" then
        for _, data in ipairs(digButtons) do
            if keys[data.keybind] then
                self.activeDesgination = data.key
                self:runCurrentCommand(true)
            end
        end
        for _, data in ipairs(buttons) do
            if keys[data.keybind] then
                data.callback(self)
            end
        end
        if keys.SELECT then
            --self:pasteBuffer(copyall(df.global.cursor))
        end
    end

    if keys.LEAVESCREEN then
        self:dismiss()
    elseif self:propagateMoveKeys(keys) then
        return
    end
end

if not (dfhack.gui.getCurFocus():match("^dwarfmode/Default") or dfhack.gui.getCurFocus():match("^dwarfmode/Designate") or dfhack.gui.getCurFocus():match("^dwarfmode/LookAround"))then
    qerror("This screen requires the main dwarfmode view or the designation screen")
end

local list = DigshapeUI{state="mark", blink=false,cull=true}
list:show()