package.path = package.path .. ";./?.lua"
local json = require("dkjson")

dofile('getUnitBaseIdsList.lua')
dofile('getUnitIconPaths.lua')

local function readCSVtoTable(filename)
  local file = io.open(filename, "r")
  if not file then
    error("Could not open file: " .. filename)
  end

  local data = {}
  local headers = {}

  local line = file:read()
  for header in line:gmatch("[^,]+") do
      table.insert(headers, header)
  end

  for line in file:lines() do
      -- Skip tier marker rows
      if not line:match("^Tier %d") then
        local row = {}
        local i = 1
        for value in line:gmatch("[^,]+") do
            row[headers[i]] = value
            print(headers[i], value)
            i = i + 1
        end
        table.insert(data, row)
      end
  end

  file:close()
  return data
end

local unitData = readCSVtoTable('builder_units_fixed.csv')

local function getColumnValueAsNumber(row, columnName)
  return tonumber(row[columnName])
end

local function writeTableToFile(table, indent, file)
  indent = indent or ""
  for key, value in pairs(table) do
      if type(value) == "table" then
          file:write(indent .. tostring(key) .. ":")
          writeTableToFile(value, indent .. "  ", file)
      else
          file:write(indent .. tostring(key) .. ": " .. tostring(value))
      end
  end
end

local sharedUnitDataTable = {}
for i, row in ipairs(unitData) do
  -- Create the unit
  local unitId = string.format("u%03d", i + 199)
  local unitBaseId = row['BaseID']
  local unit = UnitDefinition:new(unitId, unitBaseId)
  local unitName = row['Name']
  unit:setName(unitName)
  local maxBaseHp = getColumnValueAsNumber(row, "HP")
  unit:setHitPointsMaximumBase(maxBaseHp)
  local attackDamageBase = getColumnValueAsNumber(row, "Damage")
  unit:setAttack1DamageBase(attackDamageBase)
  local attackRange = getColumnValueAsNumber(row, 'Range')
  unit:setAttack1Range(attackRange)
  if tonumber(attackRange) > 100 then
    unit:setAttack1ProjectileSpeed(1200)
    unit:setAttack1ProjectileHomingEnabled(true)
  end
  local attackSpeed = getColumnValueAsNumber(row, 'Att Speed')
  unit:setAttack1CooldownTime(attackSpeed)
  unit:setArmorType('normal')
  local armorBase = getColumnValueAsNumber(row, 'Armor')
  unit:setDefenseBase(armorBase)
  unit:setMinimumAttackRange(0)
  local abilities = row['Abilities'] or ''
  unit:setNormalAbilities(abilities)
  unit:setMovementType(MovementType.Foot)
  local moveSpeed = getColumnValueAsNumber(row, 'Mov Speed')
  unit:setSpeedBase(moveSpeed)

  -- Create the corresponding building
  local buildingId = string.format("b%03d", i + 199)
  local building = UnitDefinition:new(buildingId, 'hbar')  -- Using barracks as base
  building:setName(unitName)
  building:setBuildTime(2)
  building:setModelFile(unit:getModelFile())  -- Use same model as unit
  local goldCost = getColumnValueAsNumber(row, 'Gold cost')
  building:setGoldCost(goldCost or 0)

  -- Apply unit properties to building
  building:setHitPointsMaximumBase(maxBaseHp)
  building:setAttack1DamageBase(attackDamageBase)
  building:setAttack1Range(attackRange)
  if tonumber(attackRange) > 100 then
    building:setAttack1ProjectileSpeed(1200)
    building:setAttack1ProjectileHomingEnabled(true)
  end
  building:setAttack1CooldownTime(attackSpeed)
  building:setArmorType('normal')
  building:setDefenseBase(armorBase)
  building:setMinimumAttackRange(0)
  building:setNormalAbilities(abilities)
  building:setAttack1TargetsAllowed('')  -- Empty targets allowed

  local sharedUnitData = {
    unitId = unitId,
    buildingId = buildingId,
    unitBaseId = unitBaseId,
    unitName = unitName,
  }
  sharedUnitDataTable[unitId] = sharedUnitData
end


local sharedUnitDataPath = "C:\\Users\\Kyle\\workspace\\wc3\\wc3maps\\legion_forever\\shared\\builder_unit_data.json"
local sharedUnitDataFile = io.open(sharedUnitDataPath, "w")
if sharedUnitDataFile then
  sharedUnitDataFile:write(json.encode(sharedUnitDataTable, {indent = true}))
  sharedUnitDataFile:close()
end
