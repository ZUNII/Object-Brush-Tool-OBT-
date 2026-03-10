local sx, sy = guiGetScreenSize()
local brushUI = {}
local lastBrushTime = 0
local BRUSH_COOLDOWN = 150 

-- Create GUI
function createBrushGUI()
    -- Increased height to 420 for the new button
    brushUI.window = guiCreateWindow(sx - 320, sy / 2 - 210, 300, 420, "Object Brush Tool", false)
    guiWindowSetSizable(brushUI.window, false)
    guiSetVisible(brushUI.window, false)

    -- Object ID
    guiCreateLabel(10, 30, 100, 20, "Object ID:", false, brushUI.window)
    brushUI.objID = guiCreateEdit(110, 25, 180, 25, "1337", false, brushUI.window)

    -- Radius
    guiCreateLabel(10, 70, 100, 20, "Radius:", false, brushUI.window)
    brushUI.radiusScroll = guiCreateScrollBar(110, 70, 140, 20, true, false, brushUI.window)
    guiScrollBarSetScrollPosition(brushUI.radiusScroll, 20)
    brushUI.radiusLabel = guiCreateLabel(260, 70, 30, 20, "10", false, brushUI.window)

    -- Density
    guiCreateLabel(10, 110, 100, 20, "Density:", false, brushUI.window)
    brushUI.densityScroll = guiCreateScrollBar(110, 110, 140, 20, true, false, brushUI.window)
    guiScrollBarSetScrollPosition(brushUI.densityScroll, 10)
    brushUI.densityEdit = guiCreateEdit(260, 105, 30, 30, "5", false, brushUI.window)

    -- Size (Scale)
    guiCreateLabel(10, 150, 100, 20, "Size (Scale):", false, brushUI.window)
    brushUI.scaleEdit = guiCreateEdit(110, 145, 180, 25, "1.0", false, brushUI.window)

    -- Z-Offset
    guiCreateLabel(10, 190, 100, 20, "Z-Offset (Height):", false, brushUI.window)
    brushUI.offsetEdit = guiCreateEdit(110, 185, 180, 25, "0.0", false, brushUI.window)

    -- Collisions Toggle
    brushUI.collisionCheck = guiCreateCheckBox(10, 230, 280, 20, "Enable Collisions", true, false, brushUI.window)

    -- Undo Button
    brushUI.undoBtn = guiCreateButton(10, 260, 280, 30, "Undo Last Stroke (Z)", false, brushUI.window)
    
    -- NEW: Clear All Button
    brushUI.clearBtn = guiCreateButton(10, 300, 280, 30, "Clear All Brushed Objects", false, brushUI.window)

    -- Info (Moved down to 340)
    guiCreateLabel(10, 340, 280, 60, "Press 'B' to close menu & stop brushing.\nPress 'Z' while brushing to Undo.", false, brushUI.window)

    -- Update Labels dynamically
    addEventHandler("onClientGUIScroll", brushUI.radiusScroll, function()
        local val = math.floor(guiScrollBarGetScrollPosition(source) / 2) + 1
        guiSetText(brushUI.radiusLabel, tostring(val))
    end, false)

    addEventHandler("onClientGUIScroll", brushUI.densityScroll, function()
        local val = math.floor(guiScrollBarGetScrollPosition(source) / 5) + 1
        guiSetText(brushUI.densityEdit, tostring(val))
    end, false)

    -- Button Click Handlers
    addEventHandler("onClientGUIClick", brushUI.undoBtn, function()
        triggerServerEvent("onBrushUndo", resourceRoot)
    end, false)

    addEventHandler("onClientGUIClick", brushUI.clearBtn, function()
        triggerServerEvent("onBrushClearAll", resourceRoot)
    end, false)
end
addEventHandler("onClientResourceStart", resourceRoot, createBrushGUI)

-- Toggle Menu
bindKey("b", "down", function()
    local state = not guiGetVisible(brushUI.window)
    guiSetVisible(brushUI.window, state)
    showCursor(state)
end)

-- Undo Hotkey
bindKey("z", "down", function()
    if guiGetVisible(brushUI.window) then
        triggerServerEvent("onBrushUndo", resourceRoot)
    end
end)

-- Helper to check if cursor is over our GUI
function isMouseOverGUI(cx, cy)
    if not guiGetVisible(brushUI.window) then return false end
    local wx, wy = guiGetPosition(brushUI.window, false)
    local ww, wh = guiGetSize(brushUI.window, false)
    return (cx >= wx and cx <= wx + ww and cy >= wy and cy <= wy + wh)
end

-- Math & Visuals
addEventHandler("onClientRender", root, function()
    if not guiGetVisible(brushUI.window) then return end

    local cx, cy = getCursorPosition()
    if not cx then return end

    local absX, absY = cx * sx, cy * sy
    if isMouseOverGUI(absX, absY) then return end

    local camX, camY, camZ = getCameraMatrix()
    local cursorX, cursorY, cursorZ = getWorldFromScreenPosition(absX, absY, 1000)
    local hit, hitX, hitY, hitZ = processLineOfSight(camX, camY, camZ, cursorX, cursorY, cursorZ, true, false, false, true, false, true)

    if hit then
        local radius = tonumber(guiGetText(brushUI.radiusLabel)) or 10
        local zOffset = tonumber(guiGetText(brushUI.offsetEdit)) or 0.0
        
        local segments = 36
        for i = 0, segments - 1 do
            local angle1 = (i / segments) * math.pi * 2
            local angle2 = ((i + 1) / segments) * math.pi * 2

            local px1 = hitX + math.cos(angle1) * radius
            local py1 = hitY + math.sin(angle1) * radius
            local px2 = hitX + math.cos(angle2) * radius
            local py2 = hitY + math.sin(angle2) * radius
            
            local g1 = getGroundPosition(px1, py1, hitZ + 50) or hitZ
            local g2 = getGroundPosition(px2, py2, hitZ + 50) or hitZ

            dxDrawLine3D(px1, py1, g1 + 0.1 + zOffset, px2, py2, g2 + 0.1 + zOffset, tocolor(255, 0, 0, 200), 2)
        end

        if getKeyState("mouse1") and getTickCount() - lastBrushTime > BRUSH_COOLDOWN then
            lastBrushTime = getTickCount()
            brushObjects(hitX, hitY, hitZ, radius, zOffset)
        end
    end
end)

function brushObjects(cX, cY, cZ, radius, zOffset)
    local objID = tonumber(guiGetText(brushUI.objID))
    local density = tonumber(guiGetText(brushUI.densityEdit)) or 1
    local scale = tonumber(guiGetText(brushUI.scaleEdit)) or 1.0
    local collisions = guiCheckBoxGetSelected(brushUI.collisionCheck)

    if not objID then return end

    local objectsToSpawn = {}
    for i = 1, density do
        local angle = math.random() * math.pi * 2
        local dist = math.random() * radius
        local pX = cX + math.cos(angle) * dist
        local pY = cY + math.sin(angle) * dist
        local pZ = (getGroundPosition(pX, pY, cZ + 50) or cZ) + zOffset
        local rotZ = math.random(0, 360)

        table.insert(objectsToSpawn, {objID, pX, pY, pZ, rotZ, scale, collisions})
    end

    playSoundFrontEnd(1) 
    triggerServerEvent("onBrushCreateObjects", resourceRoot, objectsToSpawn)
end
