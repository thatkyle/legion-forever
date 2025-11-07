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
      local row = {}
      local i = 1
      for value in line:gmatch("[^,]+") do
          row[headers[i]] = value
          print(headers[i], value)
          i = i + 1
      end
      table.insert(data, row)
  end

  file:close()
  return data
end

local unitData = readCSVtoTable('wave_units.csv')

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
  local unitId = string.format("u%03d", i)
  local unitBaseId = row['BaseID']
  local unit = UnitDefinition:new(unitId, unitBaseId)
  local unitName = row['New Unit']
  unit:setName(unitName)
  local maxBaseHp = getColumnValueAsNumber(row, "HP1")
  unit:setHitPointsMaximumBase(maxBaseHp)
  local attackDamageBase = getColumnValueAsNumber(row, "ADmax")
  unit:setAttack1DamageBase(attackDamageBase)
  local attackRange = getColumnValueAsNumber(row, 'Range')
  unit:setAttack1Range(attackRange)
  if tonumber(attackRange) > 100 then
    unit:setAttack1ProjectileSpeed(1200)
    unit:setAttack1ProjectileHomingEnabled(true)
  end
  local attackSpeed = getColumnValueAsNumber(row, 'AS')
  unit:setAttack1CooldownTime(attackSpeed)
  unit:setArmorType('normal')
  local armorBase = getColumnValueAsNumber(row, 'AR')
  unit:setDefenseBase(armorBase)
  unit:setMinimumAttackRange(0)
  unit:setNormalAbilities('')
  unit:setMovementType(MovementType.Foot)
  unit:setSpeedBase(350)
  local sharedUnitData = {
    unitId = unitId,
    unitBaseId = unitBaseId,
    unitName = unitName,
  }
  sharedUnitDataTable[unitId] = sharedUnitData
end


local sharedUnitDataPath = "C:\\Users\\Kyle\\workspace\\wc3\\wc3maps\\legion_forever\\shared\\unit_data.json"
local sharedUnitDataFile = io.open(sharedUnitDataPath, "w")
if sharedUnitDataFile then
  sharedUnitDataFile:write(json.encode(sharedUnitDataTable, {indent = true}))
  sharedUnitDataFile:close()
end