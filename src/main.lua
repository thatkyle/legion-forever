print('Hello warcraft-vscode !')

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Calls a callback function for each active player in the game
function ForEachActivePlayer(callback)
    for i = 0, bj_MAX_PLAYERS - 1 do
        local player = Player(i)
        if GetPlayerSlotState(player) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(player) == MAP_CONTROL_USER then
            callback(player, i)
        end
    end
end

-- Spawns units at intervals in random points within a region using wave properties
-- Parameters: region (rect), waveIndex (number), owningPlayer (player)
function SpawnUnitsInRegion(region, waveIndex, owningPlayer)
    -- Get wave properties from waves table
    local wave = waves[waveIndex]

    if not wave then
        print("Error: Wave " .. waveIndex .. " does not exist!")
        return
    end

    local unitsSpawned = 0

    local function spawnUnit()
        if unitsSpawned >= wave.quantity then
            return
        end

        -- Get random point in region
        local minX = GetRectMinX(region)
        local maxX = GetRectMaxX(region)
        local minY = GetRectMinY(region)
        local maxY = GetRectMaxY(region)

        local x = minX + math.random() * (maxX - minX)
        local y = minY + math.random() * (maxY - minY)

        -- Create unit using wave type
        local unit = CreateUnit(owningPlayer, FourCC(wave.type), x, y, math.random(0, 359))

        -- Set unit HP from wave properties
        BlzSetUnitMaxHP(unit, wave.hp)
        SetUnitLifePercentBJ(unit, 100)

        -- Set unit attack damage
        BlzSetUnitBaseDamage(unit, wave.attackDamageMin, 0)
        BlzSetUnitDiceNumber(unit, 1, 0)
        BlzSetUnitDiceSides(unit, wave.attackDamageMax - wave.attackDamageMin, 0)

        unitsSpawned = unitsSpawned + 1

        -- Add unit to playersUnits table if owner is players 9-16 (indices 8-15)
        local playerId = GetPlayerId(owningPlayer)
        if playerId >= 8 and playerId <= 15 then
            local tableIndex = playerId - 7  -- Player 8 -> index 1, Player 9 -> index 2, etc.
            if playersUnits[tableIndex] then
                playersUnits[tableIndex][unit] = true
            end
        end

        -- Schedule next spawn if more units remain
        if unitsSpawned < wave.quantity then
            TimerStart(CreateTimer(), wave.spawnInterval, false, spawnUnit)
        end
    end

    -- Start the first spawn
    print("Spawning wave " .. waveIndex .. ": " .. wave.name .. " (Quantity: " .. wave.quantity .. ")")
    spawnUnit()
end

-- Checks if all tables in playersUnits are empty
function AreAllPlayerUnitsEmpty()
    for i = 1, 8 do
        if playersUnits[i] and next(playersUnits[i]) ~= nil then
            return false
        end
    end
    return true
end

-- Placeholder function called for each active player during build phase
function rollPlayerUnits(player, playerIndex)
    print("Rolling units for player " .. playerIndex)
    -- Add your unit rolling logic here
end

-- Toggles pause/unpause for all builder units
function ToggleAllBuilderUnitsPause()
    -- Determine pause state from the first unit found (if any)
    local shouldPause = nil

    for playerIndex, units in pairs(playersBuilderUnits) do
        if units and #units > 0 and units[1] and units[1].unit then
            -- Check if first unit is paused (we'll use this as reference)
            -- If paused, we unpause all. If unpaused, we pause all.
            -- Note: There's no direct "IsUnitPaused" function, so we track state
            shouldPause = not BlzGetUnitBooleanField(units[1].unit, UNIT_BF_PAUSED)
            break
        end
    end

    -- If no units found, default to pause
    if shouldPause == nil then
        shouldPause = true
    end

    -- Apply pause/unpause to all builder units
    for playerIndex, units in pairs(playersBuilderUnits) do
        if units then
            for _, unitData in ipairs(units) do
                if unitData and unitData.unit then
                    PauseUnit(unitData.unit, shouldPause)
                end
            end
        end
    end

    if shouldPause then
        print("All builder units paused")
    else
        print("All builder units unpaused")
    end
end

-- Called when a player finishes constructing a building
-- Adds the building and its data to playersBuilderUnits
function OnBuildingConstructionFinished(constructedBuilding, owningPlayer)
    local playerIndex = GetPlayerId(owningPlayer)
    local buildingTypeId = GetUnitTypeId(constructedBuilding)
    local buildingTypeString = string.char(
        buildingTypeId % 256,
        math.floor(buildingTypeId / 256) % 256,
        math.floor(buildingTypeId / 65536) % 256,
        math.floor(buildingTypeId / 16777216) % 256
    )

    -- Check if this is a builder building (starts with 'b' and is in range b200-b3xx)
    if buildingTypeString:sub(1, 1) == 'b' then
        -- Extract the number part (e.g., "b205" -> "205")
        local buildingNumber = buildingTypeString:sub(2)

        -- Convert building ID to corresponding unit ID (b205 -> u205)
        local unitTypeString = 'u' .. buildingNumber
        local unitTypeId = FourCC(unitTypeString)

        -- Get building location
        local buildingX = GetUnitX(constructedBuilding)
        local buildingY = GetUnitY(constructedBuilding)

        -- Get gold cost
        local goldCost = GetUnitGoldCost(buildingTypeId)

        -- Create unit table entry
        local unitTable = {
            building = constructedBuilding,
            buildingType = buildingTypeString,
            unitType = unitTypeString,
            location = {x = buildingX, y = buildingY},
            goldPrice = goldCost,
            unit = nil  -- Will be set when building is replaced with unit
        }

        -- Add to player's builder units
        if not playersBuilderUnits[playerIndex] then
            playersBuilderUnits[playerIndex] = {}
        end
        table.insert(playersBuilderUnits[playerIndex], unitTable)

        print("Building " .. buildingTypeString .. " added to player " .. playerIndex .. " at (" .. buildingX .. ", " .. buildingY .. ")")
    end
end

-- Creates all buildings from playersBuilderUnits tables at their stored locations
function placeAllPlayersBuildings()
    for playerIndex, units in pairs(playersBuilderUnits) do
        if units then
            local player = Player(playerIndex)
            for _, unitData in ipairs(units) do
                if unitData and unitData.location then
                    -- Create building at stored location
                    local building = CreateUnit(
                        player,
                        FourCC(unitData.buildingType),
                        unitData.location.x,
                        unitData.location.y,
                        270
                    )

                    -- Update the building reference
                    unitData.building = building

                    print("Placed building " .. unitData.buildingType .. " for player " .. playerIndex .. " at (" .. unitData.location.x .. ", " .. unitData.location.y .. ")")
                end
            end
        end
    end
end

-- Replaces all buildings with their corresponding units
function replaceAllPlayersBuildings()
    for playerIndex, units in pairs(playersBuilderUnits) do
        if units then
            local player = Player(playerIndex)
            for _, unitData in ipairs(units) do
                if unitData then
                    -- Remove the building if it exists
                    if unitData.building then
                        RemoveUnit(unitData.building)
                        unitData.building = nil
                    end

                    -- Create the unit at the stored location
                    if unitData.location and unitData.unitType then
                        local unit = CreateUnit(
                            player,
                            FourCC(unitData.unitType),
                            unitData.location.x,
                            unitData.location.y,
                            270
                        )

                        -- Set the unit property
                        unitData.unit = unit

                        print("Replaced building with unit " .. unitData.unitType .. " for player " .. playerIndex .. " at (" .. unitData.location.x .. ", " .. unitData.location.y .. ")")
                    end
                end
            end
        end
    end
end

-- Function called when wave starts
function startWave()
    print("=== Starting Wave " .. CurrentWave .. " ===")

    -- Check if wave exists
    if not waves[CurrentWave] then
        print("All waves completed! Victory!")
        return
    end

    local wave = waves[CurrentWave]
    print("Wave " .. CurrentWave .. ": " .. wave.name)
    print("Quantity: " .. wave.quantity .. " | HP: " .. wave.hp .. " | Bounty: " .. wave.bounty)

    -- Spawn wave units for each player (players 9-16, indices 8-15)
    -- Each player gets their own set of wave units in their spawn region
    for i = 1, 8 do
        local playerId = i + 7  -- Player 8 -> playerId 8, Player 9 -> playerId 9, etc.
        local spawnRegion = playersSpawns[i]
        SpawnUnitsInRegion(spawnRegion, CurrentWave, Player(playerId))
    end
end

-- Function called when all player units are dead (wave ends)
function startBuildPhase()
    print("=== Wave " .. CurrentWave .. " Complete! ===")

    -- Increment to next wave
    CurrentWave = CurrentWave + 1

    print("All units eliminated! Starting build phase...")

    -- Create countdown timer (30 seconds)
    local buildTimer = CreateTimer()
    local buildDuration = 30.0

    -- Create timer dialog (proper method from modding.txt)
    local timerDialog = CreateTimerDialog(buildTimer)
    TimerDialogSetTitle(timerDialog, "Wave Starts In:")
    TimerDialogDisplay(timerDialog, true)

    -- Optional: Position dialog in upper right (after creating)
    local timerFrame = BlzGetFrameByName("TimerDialog", 0)
    if timerFrame then
        BlzFrameClearAllPoints(timerFrame)
        BlzFrameSetAbsPoint(timerFrame, FRAMEPOINT_TOPRIGHT, 0.8, 0.55)
    end

    -- Call rollPlayerUnits for each active player
    ForEachActivePlayer(function(player, playerIndex)
        rollPlayerUnits(player, playerIndex)
    end)

    -- Start the countdown timer (dialog will automatically count down)
    TimerStart(buildTimer, buildDuration, false, function()
        -- Hide and destroy timer dialog when countdown completes
        TimerDialogDisplay(timerDialog, false)
        DestroyTimerDialog(timerDialog)

        -- Start the next wave
        startWave()
    end)
end

-- ============================================
-- GAME STATE TRACKING
-- ============================================

-- Track units for players 9-16 (8 player slots)
playersUnits = {}
for i = 1, 8 do
    playersUnits[i] = {}
end

-- Track builder units for each active human player
-- Structure: playersBuilderUnits[playerIndex] = { {unit = <unit>}, {unit = <unit>}, ... }
playersBuilderUnits = {}
ForEachActivePlayer(function(player, playerIndex)
    playersBuilderUnits[playerIndex] = {}
end)

-- Track building areas for each player slot (nil if slot is empty)
-- Structure: playersBuildingAreas[playerIndex] = { rect1 = <rect>, rect2 = <rect> } or nil
playersBuildingAreas = {}
for i = 0, bj_MAX_PLAYERS - 1 do
    local player = Player(i)
    if GetPlayerSlotState(player) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(player) == MAP_CONTROL_USER then
        -- Active human player - create building area table with 2 rects
        -- TODO: Define actual rect coordinates for each player
        playersBuildingAreas[i] = {
            rect1 = nil,  -- Will be set later
            rect2 = nil   -- Will be set later
        }
    else
        -- Empty slot
        playersBuildingAreas[i] = nil
    end
end

-- Current wave number (increments when wave ends)
CurrentWave = 1

-- ============================================
-- WAVE DEFINITIONS
-- ============================================

-- Table of waves with creep properties
waves = {
    -- Wave 1: Crab
    {
        type = 'u001',
        name = "Crab",
        hp = 100,
        quantity = 100,
        armorType = "Unarmored",
        attackType = "Pierce",
        attackSpeed = 0.9,
        attackRange = 90,
        movementSpeed = 235,
        isFlying = false,
        attackDamageMin = 7,
        attackDamageMax = 9,
        bounty = 5,
        ccValue = 1.0,
        spawnInterval = 0.5,
        endWaveValue = 50,
        abilities = "-"
    },
    -- Wave 2: Murloc
    {
        type = 'u002',
        name = "Murloc",
        hp = 155,
        quantity = 100,
        armorType = "Unarmored",
        attackType = "Normal",
        attackSpeed = 0.9,
        attackRange = 90,
        movementSpeed = 275,
        isFlying = false,
        attackDamageMin = 10,
        attackDamageMax = 14,
        bounty = 8,
        ccValue = 1.0,
        spawnInterval = 0.5,
        endWaveValue = 100,
        abilities = "-"
    },
    -- Wave 3: Scorpion
    {
        type = 'u003',
        name = "Scorpion",
        hp = 250,
        quantity = 100,
        armorType = "Medium",
        attackType = "Normal",
        attackSpeed = 0.9,
        attackRange = 90,
        movementSpeed = 325,
        isFlying = false,
        attackDamageMin = 14,
        attackDamageMax = 15,
        bounty = 12,
        ccValue = 1.0,
        spawnInterval = 0.5,
        endWaveValue = 150,
        abilities = "-"
    },
    -- Wave 4: Quilbeast
    {
        type = 'u004',
        name = "Quilbeast",
        hp = 250,
        quantity = 100,
        armorType = "Heavy",
        attackType = "Pierce",
        attackSpeed = 0.9,
        attackRange = 400,
        movementSpeed = 300,
        isFlying = false,
        attackDamageMin = 14,
        attackDamageMax = 16,
        bounty = 14,
        ccValue = 1.0,
        spawnInterval = 0.5,
        endWaveValue = 200,
        abilities = "-"
    },
    -- Wave 5: Hawk
    {
        type = 'u005',
        name = "Hawk",
        hp = 350,
        quantity = 100,
        armorType = "Light",
        attackType = "Magic",
        attackSpeed = 0.9,
        attackRange = 90,
        movementSpeed = 320,
        isFlying = true,
        attackDamageMin = 31,
        attackDamageMax = 33,
        bounty = 18,
        ccValue = 0.8,
        spawnInterval = 0.4,
        endWaveValue = 250,
        abilities = "-"
    },
    -- Wave 6: Rock Golem
    {
        type = 'u006',
        name = "Rock Golem",
        hp = 501,
        quantity = 100,
        armorType = "Fortified",
        attackType = "Siege",
        attackSpeed = 1.0,
        attackRange = 90,
        movementSpeed = 300,
        isFlying = false,
        attackDamageMin = 47,
        attackDamageMax = 48,
        bounty = 25,
        ccValue = 2.0,
        spawnInterval = 0.6,
        endWaveValue = 300,
        abilities = "Fortified Unit"
    },
    -- Wave 7: Satyr
    {
        type = 'u007',
        name = "Satyr",
        hp = 600,
        quantity = 100,
        armorType = "Light",
        attackType = "Pierce",
        attackSpeed = 1.1,
        attackRange = 100,
        movementSpeed = 320,
        isFlying = false,
        attackDamageMin = 49,
        attackDamageMax = 51,
        bounty = 30,
        ccValue = 1.0,
        spawnInterval = 0.5,
        endWaveValue = 350,
        abilities = "-"
    },
    -- Wave 8: Acolyte
    {
        type = 'u008',
        name = "Acolyte",
        hp = 530,
        quantity = 100,
        armorType = "Medium",
        attackType = "Magic",
        attackSpeed = 0.9,
        attackRange = 400,
        movementSpeed = 300,
        isFlying = false,
        attackDamageMin = 26,
        attackDamageMax = 30,
        bounty = 28,
        ccValue = 1.0,
        spawnInterval = 0.4,
        endWaveValue = 400,
        abilities = "-"
    },
    -- Wave 9: Zombie
    {
        type = 'u009',
        name = "Zombie",
        hp = 1075,
        quantity = 100,
        armorType = "Heavy",
        attackType = "Normal",
        attackSpeed = 0.9,
        attackRange = 120,
        movementSpeed = 320,
        isFlying = false,
        attackDamageMin = 57,
        attackDamageMax = 59,
        bounty = 50,
        ccValue = 1.5,
        spawnInterval = 0.5,
        endWaveValue = 450,
        abilities = "-"
    },
    -- Wave 10: Draenei Chieftain (BOSS)
    {
        type = 'u010',
        name = "Draenei Chieftain",
        hp = 5800,
        quantity = 12,
        armorType = "Light",
        attackType = "Chaos",
        attackSpeed = 0.42,
        attackRange = 180,
        movementSpeed = 200,
        isFlying = false,
        attackDamageMin = 200,
        attackDamageMax = 220,
        bounty = 500,
        ccValue = 5.0,
        spawnInterval = 1.0,
        endWaveValue = 500,
        abilities = "Boss Unit"
    },
    -- Wave 11: Clockwerk Goblin
    {
        type = 'u011',
        name = "Clockwerk Goblin",
        hp = 1250,
        quantity = 100,
        armorType = "Fortified",
        attackType = "Siege",
        attackSpeed = 0.8,
        attackRange = 90,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 76,
        attackDamageMax = 78,
        bounty = 60,
        ccValue = 2.0,
        spawnInterval = 0.5,
        endWaveValue = 550,
        abilities = "Fortified Unit"
    },
    -- Wave 12: Siren
    {
        type = 'u012',
        name = "Siren",
        hp = 1050,
        quantity = 100,
        armorType = "Medium",
        attackType = "Pierce",
        attackSpeed = 0.77,
        attackRange = 400,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 44,
        attackDamageMax = 46,
        bounty = 55,
        ccValue = 1.2,
        spawnInterval = 0.4,
        endWaveValue = 600,
        abilities = "King's Defiance, Regicide (Siren)"
    },
    -- Wave 13: Couatl
    {
        type = 'u013',
        name = "Couatl",
        hp = 1400,
        quantity = 100,
        armorType = "Light",
        attackType = "Magic",
        attackSpeed = 0.8,
        attackRange = 90,
        movementSpeed = 345,
        isFlying = true,
        attackDamageMin = 91,
        attackDamageMax = 94,
        bounty = 70,
        ccValue = 1.0,
        spawnInterval = 0.5,
        endWaveValue = 650,
        abilities = "-"
    },
    -- Wave 14: Tuskar Warrior
    {
        type = 'u014',
        name = "Tuskar Warrior",
        hp = 2350,
        quantity = 100,
        armorType = "Medium",
        attackType = "Normal",
        attackSpeed = 0.85,
        attackRange = 90,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 124,
        attackDamageMax = 126,
        bounty = 100,
        ccValue = 1.5,
        spawnInterval = 0.5,
        endWaveValue = 700,
        abilities = "King's Defiance, Regicide (Siren)"
    },
    -- Wave 15: Centaur
    {
        type = 'u015',
        name = "Centaur",
        hp = 2550,
        quantity = 100,
        armorType = "Heavy",
        attackType = "Normal",
        attackSpeed = 0.83,
        attackRange = 120,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 150,
        attackDamageMax = 155,
        bounty = 120,
        ccValue = 1.8,
        spawnInterval = 0.5,
        endWaveValue = 750,
        abilities = "-"
    },
    -- Wave 16: Lightning Chicken
    {
        type = 'u016',
        name = "Lightning Chicken",
        hp = 1300,
        quantity = 100,
        armorType = "Light",
        attackType = "Magic",
        attackSpeed = 0.63,
        attackRange = 400,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 100,
        attackDamageMax = 112,
        bounty = 75,
        ccValue = 1.0,
        spawnInterval = 0.4,
        endWaveValue = 800,
        abilities = "-"
    },
    -- Wave 17: Flesh Golem
    {
        type = 'u017',
        name = "Flesh Golem",
        hp = 2900,
        quantity = 100,
        armorType = "Fortified",
        attackType = "Siege",
        attackSpeed = 0.81,
        attackRange = 150,
        movementSpeed = 325,
        isFlying = false,
        attackDamageMin = 179,
        attackDamageMax = 183,
        bounty = 140,
        ccValue = 2.0,
        spawnInterval = 0.6,
        endWaveValue = 850,
        abilities = "Fortified Unit"
    },
    -- Wave 18: Sludge Flinger
    {
        type = 'u018',
        name = "Sludge Flinger",
        hp = 3600,
        quantity = 100,
        armorType = "Medium",
        attackType = "Magic",
        attackSpeed = 0.64,
        attackRange = 150,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 200,
        attackDamageMax = 205,
        bounty = 160,
        ccValue = 1.5,
        spawnInterval = 0.5,
        endWaveValue = 900,
        abilities = "-"
    },
    -- Wave 19: Giant Spider
    {
        type = 'u019',
        name = "Giant Spider",
        hp = 3700,
        quantity = 100,
        armorType = "Light",
        attackType = "Pierce",
        attackSpeed = 0.7,
        attackRange = 150,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 201,
        attackDamageMax = 201,
        bounty = 170,
        ccValue = 1.2,
        spawnInterval = 0.5,
        endWaveValue = 950,
        abilities = "-"
    },
    -- Wave 20: Dragon Turtle (BOSS)
    {
        type = 'u020',
        name = "Dragon Turtle",
        hp = 18500,
        quantity = 12,
        armorType = "Divine",
        attackType = "Chaos",
        attackSpeed = 0.47,
        attackRange = 425,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 200,
        attackDamageMax = 230,
        bounty = 1500,
        ccValue = 8.0,
        spawnInterval = 1.0,
        endWaveValue = 1000,
        abilities = "Torrent, Boss Unit"
    },
    -- Wave 21: Hippogryph
    {
        type = 'u021',
        name = "Hippogryph",
        hp = 11900,
        quantity = 50,
        armorType = "Light",
        attackType = "Pierce",
        attackSpeed = 0.6,
        attackRange = 180,
        movementSpeed = 350,
        isFlying = true,
        attackDamageMin = 223,
        attackDamageMax = 230,
        bounty = 500,
        ccValue = 1.0,
        spawnInterval = 0.4,
        endWaveValue = 1050,
        abilities = "-"
    },
    -- Wave 22: Mammoth
    {
        type = 'u022',
        name = "Mammoth",
        hp = 18600,
        quantity = 50,
        armorType = "Fortified",
        attackType = "Siege",
        attackSpeed = 1.15,
        attackRange = 120,
        movementSpeed = 275,
        isFlying = false,
        attackDamageMin = 221,
        attackDamageMax = 233,
        bounty = 800,
        ccValue = 3.0,
        spawnInterval = 0.7,
        endWaveValue = 1100,
        abilities = "Fortified Unit"
    },
    -- Wave 23: Wildkin
    {
        type = 'u023',
        name = "Wildkin",
        hp = 18300,
        quantity = 50,
        armorType = "Heavy",
        attackType = "Normal",
        attackSpeed = 1.07,
        attackRange = 180,
        movementSpeed = 300,
        isFlying = false,
        attackDamageMin = 300,
        attackDamageMax = 314,
        bounty = 850,
        ccValue = 2.5,
        spawnInterval = 0.6,
        endWaveValue = 1150,
        abilities = "-"
    },
    -- Wave 24: Revenant
    {
        type = 'u024',
        name = "Revenant",
        hp = 12000,
        quantity = 50,
        armorType = "Medium",
        attackType = "Magic",
        attackSpeed = 1.0,
        attackRange = 600,
        movementSpeed = 330,
        isFlying = false,
        attackDamageMin = 210,
        attackDamageMax = 230,
        bounty = 600,
        ccValue = 1.3,
        spawnInterval = 0.5,
        endWaveValue = 1200,
        abilities = "Thunder attack"
    },
    -- Wave 25: Succubus
    {
        type = 'u025',
        name = "Succubus",
        hp = 25200,
        quantity = 50,
        armorType = "Light",
        attackType = "Pierce",
        attackSpeed = 0.8,
        attackRange = 150,
        movementSpeed = 420,
        isFlying = false,
        attackDamageMin = 330,
        attackDamageMax = 354,
        bounty = 1000,
        ccValue = 1.5,
        spawnInterval = 0.5,
        endWaveValue = 1250,
        abilities = "-"
    },
    -- Wave 26: Myrmidon
    {
        type = 'u026',
        name = "Myrmidon",
        hp = 21300,
        quantity = 50,
        armorType = "Heavy",
        attackType = "Normal",
        attackSpeed = 1.05,
        attackRange = 170,
        movementSpeed = 375,
        isFlying = false,
        attackDamageMin = 330,
        attackDamageMax = 350,
        bounty = 900,
        ccValue = 2.0,
        spawnInterval = 0.5,
        endWaveValue = 1300,
        abilities = "-"
    },
    -- Wave 27: Doom Guard
    {
        type = 'u027',
        name = "Doom Guard",
        hp = 28000,
        quantity = 50,
        armorType = "Medium",
        attackType = "Normal",
        attackSpeed = 0.8,
        attackRange = 180,
        movementSpeed = 400,
        isFlying = false,
        attackDamageMin = 285,
        attackDamageMax = 295,
        bounty = 1100,
        ccValue = 1.8,
        spawnInterval = 0.5,
        endWaveValue = 1350,
        abilities = "-"
    },
    -- Wave 28: Juggernaut
    {
        type = 'u028',
        name = "Juggernaut",
        hp = 22000,
        quantity = 50,
        armorType = "Fortified",
        attackType = "Siege",
        attackSpeed = 0.75,
        attackRange = 450,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 235,
        attackDamageMax = 245,
        bounty = 950,
        ccValue = 2.5,
        spawnInterval = 0.6,
        endWaveValue = 1400,
        abilities = "Fortified Unit"
    },
    -- Wave 29: Frost Wyrm
    {
        type = 'u029',
        name = "Frost Wyrm",
        hp = 21000,
        quantity = 50,
        armorType = "Heavy",
        attackType = "Magic",
        attackSpeed = 1.07,
        attackRange = 400,
        movementSpeed = 360,
        isFlying = true,
        attackDamageMin = 266,
        attackDamageMax = 286,
        bounty = 1000,
        ccValue = 2.0,
        spawnInterval = 0.6,
        endWaveValue = 1450,
        abilities = "-"
    },
    -- Wave 30: Magnataur (BOSS)
    {
        type = 'u030',
        name = "Magnataur",
        hp = 23000,
        quantity = 12,
        armorType = "Fortified",
        attackType = "Chaos",
        attackSpeed = 0.6,
        attackRange = 100,
        movementSpeed = 360,
        isFlying = false,
        attackDamageMin = 777,
        attackDamageMax = 888,
        bounty = 2000,
        ccValue = 10.0,
        spawnInterval = 1.0,
        endWaveValue = 1500,
        abilities = "Magnataur's Shockwave, Magnataur's Shockwave, Boss Unit, Fortified Unit"
    },
    -- Wave 31: Pit Lord (BOSS)
    {
        type = 'u031',
        name = "Pit Lord",
        hp = 18000,
        quantity = 12,
        armorType = "Unarmored",
        attackType = "Chaos",
        attackSpeed = 0.8,
        attackRange = 225,
        movementSpeed = 350,
        isFlying = false,
        attackDamageMin = 600,
        attackDamageMax = 610,
        bounty = 2200,
        ccValue = 8.0,
        spawnInterval = 1.0,
        endWaveValue = 1550,
        abilities = "Boss Unit"
    },
    -- Wave 32: Crypt Lord (BOSS)
    {
        type = 'u032',
        name = "Crypt Lord",
        hp = 30000,
        quantity = 12,
        armorType = "Light",
        attackType = "Pierce",
        attackSpeed = 0.48,
        attackRange = 225,
        movementSpeed = 400,
        isFlying = false,
        attackDamageMin = 700,
        attackDamageMax = 730,
        bounty = 2500,
        ccValue = 10.0,
        spawnInterval = 1.0,
        endWaveValue = 1600,
        abilities = "Crypt Lord Poison, Boss Unit"
    },
    -- Wave 33: War Lord (BOSS)
    {
        type = 'u033',
        name = "War Lord",
        hp = 25000,
        quantity = 12,
        armorType = "Heavy",
        attackType = "Normal",
        attackSpeed = 0.45,
        attackRange = 225,
        movementSpeed = 400,
        isFlying = false,
        attackDamageMin = 700,
        attackDamageMax = 900,
        bounty = 2600,
        ccValue = 9.0,
        spawnInterval = 1.0,
        endWaveValue = 1650,
        abilities = "Life Steal, Boss Unit"
    },
    -- Wave 34: Fire Lord (BOSS)
    {
        type = 'u034',
        name = "Fire Lord",
        hp = 15000,
        quantity = 12,
        armorType = "Medium",
        attackType = "Magic",
        attackSpeed = 0.25,
        attackRange = 450,
        movementSpeed = 400,
        isFlying = false,
        attackDamageMin = 60,
        attackDamageMax = 60,
        bounty = 2800,
        ccValue = 8.0,
        spawnInterval = 1.0,
        endWaveValue = 1700,
        abilities = "Boss Unit, Rockets"
    },
    -- Wave 35: Burning Legion (FINAL BOSS)
    {
        type = 'u035',
        name = "Burning Legion",
        hp = 100000,
        quantity = 2,
        armorType = "Fortified",
        attackType = "Chaos",
        attackSpeed = 0.4,
        attackRange = 500,
        movementSpeed = 400,
        isFlying = false,
        attackDamageMin = 1000,
        attackDamageMax = 1000,
        bounty = 5000,
        ccValue = 20.0,
        spawnInterval = 1.0,
        endWaveValue = 2000,
        abilities = "DOOM's Permanent Immolation, Boss Unit, Call to Arms"
    }
}

-- ============================================
-- KING CONSTANTS
-- ============================================

MAX_KING_HEALS = 3
MAX_KING_HEALTH_UPGRADES = 10
MAX_KING_REGEN_UPGRADES = 10
MAX_KING_ATTACK_UPGRADES = 10
MAX_KING_DARK_PRESENCE_UPGRADES = 5
MAX_KING_ROYAL_PRESENCE_UPGRADES = 5
MAX_KING_PURGE_UPGRADES = 5

-- ============================================
-- KING TABLES
-- ============================================

-- King 1 properties
king1 = {
    healsRemaining = MAX_KING_HEALS,
    healthUpgrades = 0,
    regenUpgrades = 0,
    attackUpgrades = 0,
    darkPresenceUpgrades = 0,
    royalPresenceUpgrades = 0,
    purgeUpgrades = 0,
    -- currentSpells: Can include "Shockwave", "Stomp", "Immolate", "Royal Presence", "Dark Presence", "Purge"
    currentSpells = {},
    -- currentAbilities: Can include "King's Rage", "King's Resilience"
    currentAbilities = {}
}

-- King 2 properties
king2 = {
    healsRemaining = MAX_KING_HEALS,
    healthUpgrades = 0,
    regenUpgrades = 0,
    attackUpgrades = 0,
    darkPresenceUpgrades = 0,
    royalPresenceUpgrades = 0,
    purgeUpgrades = 0,
    -- currentSpells: Can include "Shockwave", "Stomp", "Immolate", "Royal Presence", "Dark Presence", "Purge"
    currentSpells = {},
    -- currentAbilities: Can include "King's Rage", "King's Resilience"
    currentAbilities = {}
}

-- ============================================
-- KING UPDATE FUNCTIONS
-- ============================================

-- Use heal for a king (decrements healsRemaining by 1)
function UseKingHeal(king)
    if king.healsRemaining > 0 then
        king.healsRemaining = king.healsRemaining - 1
        print("King heal used. Heals remaining: " .. king.healsRemaining)
        return true
    else
        print("No heals remaining!")
        return false
    end
end

-- Upgrade king's health (increments by 1, max: MAX_KING_HEALTH_UPGRADES)
function UpgradeKingHealth(king)
    if king.healthUpgrades < MAX_KING_HEALTH_UPGRADES then
        king.healthUpgrades = king.healthUpgrades + 1
        print("King health upgraded to level " .. king.healthUpgrades)
        return true
    else
        print("King health already at max level!")
        return false
    end
end

-- Upgrade king's regen (increments by 1, max: MAX_KING_REGEN_UPGRADES)
function UpgradeKingRegen(king)
    if king.regenUpgrades < MAX_KING_REGEN_UPGRADES then
        king.regenUpgrades = king.regenUpgrades + 1
        print("King regen upgraded to level " .. king.regenUpgrades)
        return true
    else
        print("King regen already at max level!")
        return false
    end
end

-- Upgrade king's attack (increments by 1, max: MAX_KING_ATTACK_UPGRADES)
function UpgradeKingAttack(king)
    if king.attackUpgrades < MAX_KING_ATTACK_UPGRADES then
        king.attackUpgrades = king.attackUpgrades + 1
        print("King attack upgraded to level " .. king.attackUpgrades)
        return true
    else
        print("King attack already at max level!")
        return false
    end
end

-- Upgrade king's Dark Presence (increments by 1, max: MAX_KING_DARK_PRESENCE_UPGRADES)
function UpgradeKingDarkPresence(king)
    if king.darkPresenceUpgrades < MAX_KING_DARK_PRESENCE_UPGRADES then
        king.darkPresenceUpgrades = king.darkPresenceUpgrades + 1
        print("King Dark Presence upgraded to level " .. king.darkPresenceUpgrades)
        return true
    else
        print("King Dark Presence already at max level!")
        return false
    end
end

-- Upgrade king's Royal Presence (increments by 1, max: MAX_KING_ROYAL_PRESENCE_UPGRADES)
function UpgradeKingRoyalPresence(king)
    if king.royalPresenceUpgrades < MAX_KING_ROYAL_PRESENCE_UPGRADES then
        king.royalPresenceUpgrades = king.royalPresenceUpgrades + 1
        print("King Royal Presence upgraded to level " .. king.royalPresenceUpgrades)
        return true
    else
        print("King Royal Presence already at max level!")
        return false
    end
end

-- Upgrade king's Purge (increments by 1, max: MAX_KING_PURGE_UPGRADES)
function UpgradeKingPurge(king)
    if king.purgeUpgrades < MAX_KING_PURGE_UPGRADES then
        king.purgeUpgrades = king.purgeUpgrades + 1
        print("King Purge upgraded to level " .. king.purgeUpgrades)
        return true
    else
        print("King Purge already at max level!")
        return false
    end
end

-- Add spell to king's currentSpells table
-- Valid spells: "Shockwave", "Stomp", "Immolate", "Royal Presence", "Dark Presence", "Purge"
function AddKingSpell(king, spellName)
    -- Check if spell already exists
    for _, spell in ipairs(king.currentSpells) do
        if spell == spellName then
            print("King already has spell: " .. spellName)
            return false
        end
    end

    table.insert(king.currentSpells, spellName)
    print("Added spell to king: " .. spellName)
    return true
end

-- Add ability to king's currentAbilities table
-- Valid abilities: "King's Rage", "King's Resilience"
function AddKingAbility(king, abilityName)
    -- Check if ability already exists
    for _, ability in ipairs(king.currentAbilities) do
        if ability == abilityName then
            print("King already has ability: " .. abilityName)
            return false
        end
    end

    table.insert(king.currentAbilities, abilityName)
    print("Added ability to king: " .. abilityName)
    return true
end

-- ============================================
-- EVENT TRIGGERS
-- ============================================

-- Setup death trigger for players 9-16
function InitializeDeathTrigger()
    local deathTrigger = CreateTrigger()

    -- Register death event for players 9-16 (indices 8-15)
    for i = 8, 15 do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
    end

    -- Death event handler
    TriggerAddAction(deathTrigger, function()
        local dyingUnit = GetTriggerUnit()
        local owningPlayer = GetOwningPlayer(dyingUnit)
        local playerId = GetPlayerId(owningPlayer)

        -- Calculate index in playersUnits table (players 9-16 map to indices 1-8)
        local tableIndex = playerId - 7  -- Player 8 -> index 1, Player 9 -> index 2, etc.

        -- Remove unit from the player's table
        if playersUnits[tableIndex] then
            playersUnits[tableIndex][dyingUnit] = nil
        end

        -- Check if all player units are eliminated
        if AreAllPlayerUnitsEmpty() then
            startBuildPhase()
        end
    end)
end

-- Setup construction finished trigger for all players
function InitializeConstructionFinishedTrigger()
    local constructionTrigger = CreateTrigger()

    -- Register construction finished event for all players
    for i = 0, bj_MAX_PLAYERS - 1 do
        TriggerRegisterPlayerUnitEvent(constructionTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, nil)
    end

    -- Construction finished event handler
    TriggerAddAction(constructionTrigger, function()
        local constructedBuilding = GetConstructedStructure()
        local owningPlayer = GetOwningPlayer(constructedBuilding)
        OnBuildingConstructionFinished(constructedBuilding, owningPlayer)
    end)
end

-- Setup trigger for builder units leaving their building areas
function InitializeBuilderUnitAreaTrigger()
    -- Create triggers for each player's building areas
    for playerIndex = 0, bj_MAX_PLAYERS - 1 do
        local buildingAreas = playersBuildingAreas[playerIndex]

        if buildingAreas and buildingAreas.rect1 and buildingAreas.rect2 then
            local player = Player(playerIndex)

            -- Create leave trigger for rect1
            local leaveTrigger1 = CreateTrigger()
            TriggerRegisterLeaveRectSimple(leaveTrigger1, buildingAreas.rect1)
            TriggerAddCondition(leaveTrigger1, Condition(function()
                local leavingUnit = GetTriggerUnit()
                local unitOwner = GetOwningPlayer(leavingUnit)
                return unitOwner == player and GetUnitTypeId(leavingUnit) == FourCC('u999')
            end))
            TriggerAddAction(leaveTrigger1, function()
                local leavingUnit = GetTriggerUnit()
                local unitX = GetUnitX(leavingUnit)
                local unitY = GetUnitY(leavingUnit)

                -- Check if unit is in rect2
                if not RectContainsCoords(buildingAreas.rect2, unitX, unitY) then
                    -- Unit is not in rect2, teleport back to center of rect1
                    local centerX = GetRectCenterX(buildingAreas.rect1)
                    local centerY = GetRectCenterY(buildingAreas.rect1)
                    SetUnitPosition(leavingUnit, centerX, centerY)

                    -- Display message to player
                    if GetLocalPlayer() == player then
                        DisplayTextToPlayer(player, 0, 0, "Do not leave your building area")
                    end
                end
            end)

            -- Create leave trigger for rect2
            local leaveTrigger2 = CreateTrigger()
            TriggerRegisterLeaveRectSimple(leaveTrigger2, buildingAreas.rect2)
            TriggerAddCondition(leaveTrigger2, Condition(function()
                local leavingUnit = GetTriggerUnit()
                local unitOwner = GetOwningPlayer(leavingUnit)
                return unitOwner == player and GetUnitTypeId(leavingUnit) == FourCC('u999')
            end))
            TriggerAddAction(leaveTrigger2, function()
                local leavingUnit = GetTriggerUnit()
                local unitX = GetUnitX(leavingUnit)
                local unitY = GetUnitY(leavingUnit)

                -- Check if unit is in rect1
                if not RectContainsCoords(buildingAreas.rect1, unitX, unitY) then
                    -- Unit is not in rect1, teleport back to center of rect1
                    local centerX = GetRectCenterX(buildingAreas.rect1)
                    local centerY = GetRectCenterY(buildingAreas.rect1)
                    SetUnitPosition(leavingUnit, centerX, centerY)

                    -- Display message to player
                    if GetLocalPlayer() == player then
                        DisplayTextToPlayer(player, 0, 0, "Do not leave your building area")
                    end
                end
            end)
        end
    end
end

-- Initialize triggers
InitializeDeathTrigger()
InitializeConstructionFinishedTrigger()
InitializeBuilderUnitAreaTrigger()

-- Trigger to start the countdown after a brief delay
function InitializeMapStartTrigger()
    local startTrigger = CreateTrigger()

    -- Fire once when elapsed game time reaches 0.1 seconds
    TriggerRegisterTimerEvent(startTrigger, 0.1, false)

    -- Action: Create the map start countdown
    TriggerAddAction(startTrigger, function()
        CreateMapStartCountdown(10.0, "Prepare Yourselves:")
    end)
end

InitializeMapStartTrigger()

-- ============================================
-- MAP INITIALIZATION
-- ============================================

playersSpawnRectCoords = {
  { topLeft = {-7800, 6400}, bottomRight = {-6400, 5600} },
  { topLeft = {-7800, 0}, bottomRight = {-6400, -760} },
  { topLeft = {-2700, 6400}, bottomRight = {-1270, 5600} },
  { topLeft = {-2700, 0}, bottomRight = {-1270, -760} },
  { topLeft = {1270, 6400}, bottomRight = {2700, 5600} },
  { topLeft = {1270, 0}, bottomRight = {2700, -760} },
  { topLeft = {6400, 6400}, bottomRight = {7800, 5600} },
  { topLeft = {6400, 0}, bottomRight = {7800, -760} },
}
playersSpawns = {}

for i = 0, 7 do
    local coords = playersSpawnRectCoords[i + 1]
    local rect = Rect(coords.topLeft[1], coords.topLeft[2], coords.bottomRight[1], coords.bottomRight[2])

    playersSpawns[i + 1] = rect
end

-- Spawn a peasant in each region for player 1
for i = 1, 8 do
    local rect = playersSpawns[i]
    local x = GetRectCenterX(rect)
    local y = GetRectCenterY(rect)
    CreateUnit(Player(0), FourCC('hpea'), x, y, 270)  -- Player(0) is player 1
end

CreateUnit(Player(0), FourCC('H101'), 219.4, -90.4, 293.630)

-- ============================================
-- MAP START COUNTDOWN
-- ============================================

-- Creates a countdown timer dialog when the map starts
function CreateMapStartCountdown(duration, title)
    -- Create the timer
    local startTimer = CreateTimer()

    -- Create timer dialog (proper method from modding.txt)
    local timerDialog = CreateTimerDialog(startTimer)
    TimerDialogSetTitle(timerDialog, title or "Game Starts In:")
    TimerDialogDisplay(timerDialog, true)

    -- Optional: Position dialog at top center
    local timerFrame = BlzGetFrameByName("TimerDialog", 0)
    if timerFrame then
        BlzFrameClearAllPoints(timerFrame)
        BlzFrameSetAbsPoint(timerFrame, FRAMEPOINT_TOP, 0.4, 0.58)
    end

    -- Start the countdown timer
    TimerStart(startTimer, duration, false, function()
        -- Hide and destroy timer dialog when countdown completes
        TimerDialogDisplay(timerDialog, false)
        DestroyTimerDialog(timerDialog)

        -- Display message when countdown finishes
        DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "|cff00ff00Game has started!|r")

        print("Map start countdown finished!")
    end)

    return timerDialog
end

-- ============================================
-- TEST FUNCTION
-- ============================================

-- Creates one of each wave unit for testing purposes
function TestSpawnAllWaveUnits()
    print("=== Spawning Test Units ===")
    local player1 = Player(0)
    local startX = 0
    local startY = 0
    local spacing = 200
    local unitsPerRow = 7

    for i, wave in ipairs(waves) do
        -- Calculate position in a grid pattern
        local col = (i - 1) % unitsPerRow
        local row = math.floor((i - 1) / unitsPerRow)
        local x = startX + (col * spacing)
        local y = startY + (row * spacing)

        -- Create unit using wave type
        CreateUnit(player1, FourCC(wave.type), x, y, 270)

        print("Wave " .. i .. ": " .. wave.name .. " (" .. wave.type .. ") spawned at (" .. x .. ", " .. y .. ")")
    end

    print("=== Test Units Spawned: " .. #waves .. " total ===")
end

-- Uncomment the line below to test spawn all wave units
-- TestSpawnAllWaveUnits()

-- Spawns units at intervals in random points within a region with custom quantity and interval
-- Parameters: region (rect), waveIndex (number), owningPlayer (player), customQuantity (number), customInterval (number)
function SpawnUnitsInRegionCustom(region, waveIndex, owningPlayer, customQuantity, customInterval)
    local wave = waves[waveIndex]

    if not wave then
        print("Error: Wave " .. waveIndex .. " does not exist!")
        return
    end

    local unitsSpawned = 0

    local function spawnUnit()
        if unitsSpawned >= customQuantity then
            return
        end

        -- Get random point in region
        local minX = GetRectMinX(region)
        local maxX = GetRectMaxX(region)
        local minY = GetRectMinY(region)
        local maxY = GetRectMaxY(region)

        local x = minX + math.random() * (maxX - minX)
        local y = minY + math.random() * (maxY - minY)

        -- Create unit using wave type
        local unit = CreateUnit(owningPlayer, FourCC(wave.type), x, y, math.random(0, 359))

        -- Set unit HP from wave properties
        BlzSetUnitMaxHP(unit, wave.hp)
        SetUnitLifePercentBJ(unit, 100)

        -- Set unit attack damage
        BlzSetUnitBaseDamage(unit, wave.attackDamageMin, 0)
        BlzSetUnitDiceNumber(unit, 1, 0)
        BlzSetUnitDiceSides(unit, wave.attackDamageMax - wave.attackDamageMin, 0)

        unitsSpawned = unitsSpawned + 1

        -- Add unit to playersUnits table if owner is player 1 (index 0)
        local playerId = GetPlayerId(owningPlayer)
        if playerId == 0 then
            -- Use index 1 for player 1 testing
            if playersUnits[1] then
                playersUnits[1][unit] = true
            end
        end

        -- Schedule next spawn if more units remain
        if unitsSpawned < customQuantity then
            TimerStart(CreateTimer(), customInterval, false, spawnUnit)
        end
    end

    -- Start the first spawn
    spawnUnit()
end

-- Test spawning all waves in all regions with custom settings
function TestSpawnWavesInAllRegions()
    print("=== Starting Wave Spawn Test ===")
    local player1 = Player(0)
    local currentWave = 1

    local function spawnNextWave()
        if currentWave > #waves then
            print("=== All waves spawned! ===")
            return
        end

        local wave = waves[currentWave]
        local testQuantity = math.floor(wave.quantity / 10)
        local testInterval = 0.05

        print("Spawning Wave " .. currentWave .. ": " .. wave.name .. " (Test Quantity: " .. testQuantity .. " per region)")

        -- Spawn in all 8 regions
        for i = 1, 8 do
            local region = playersSpawns[i]
            SpawnUnitsInRegionCustom(region, currentWave, player1, testQuantity, testInterval)
        end

        currentWave = currentWave + 1

        -- Schedule next wave after 10 seconds
        if currentWave <= #waves then
            TimerStart(CreateTimer(), 10.0, false, spawnNextWave)
        end
    end

    -- Start spawning waves
    spawnNextWave()
end

-- Orders all units in playersUnits to attack-move to the center of the map
-- Only orders units that don't already have orders to prevent stuttering
function OrderUnitsToCenter()
    local centerX = 0
    local centerY = 0

    for i = 1, 8 do
        if playersUnits[i] then
            for unit, _ in pairs(playersUnits[i]) do
                if GetUnitTypeId(unit) ~= 0 then  -- Check if unit still exists
                    -- Only issue order if unit has no current order (is idle)
                    local currentOrder = GetUnitCurrentOrder(unit)
                    if currentOrder == 0 or currentOrder == nil then
                        IssuePointOrderById(unit, 851986, centerX, centerY)  -- 851986 is attack-move order
                    end
                end
            end
        end
    end
end

-- Starts a repeating timer that orders all units to attack-move to center every 0.5 seconds
function StartPeriodicAttackMoveToCenter()
    local attackMoveTimer = CreateTimer()

    TimerStart(attackMoveTimer, 0.1, true, function()
        OrderUnitsToCenter()
    end)

    print("Started periodic attack-move orders to center (every 0.5 seconds)")
end

-- Uncomment the lines below to test wave spawning
TestSpawnWavesInAllRegions()
StartPeriodicAttackMoveToCenter()

-- ============================================
-- GAME START
-- ============================================

-- Start the build phase when game begins
startBuildPhase()

-- TestSpawnAllWaveUnits()