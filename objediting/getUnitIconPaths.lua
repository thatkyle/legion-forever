package.path = package.path .. ";./?.lua"
local json = require("dkjson")

local allUsedUnitBaseIdsPath = '../shared/allUnitBaseIds.txt'
local outputFilePath = "../shared/unitIconPaths.json"

local function containsStringInFile(fileName, searchString)
  local file = io.open(fileName, "r") -- Open the file for reading
  if not file then
      print("File not found")
      return false
  end

  for line in file:lines() do
      if line:find(searchString, 1, true) then -- True for plain search
          file:close()
          return true
      end
  end

  file:close() -- Make sure to close the file
  return false
end

local function parseUnitFileForIconPaths(filePath)
  local units = {}
  local currentUnitId = nil
  local art, hdArt = nil, nil
  local isUnitBeingUsed = false
  local currentUnit = {}

  for line in io.lines(filePath) do
    local id = line:match("%[(.-)%]")
    if id then
      currentUnitId = id
      art, hdArt = nil, nil
      isUnitBeingUsed = containsStringInFile(allUsedUnitBaseIdsPath, id)
      currentUnit = {}
    end
    if isUnitBeingUsed and currentUnitId then
      if line:match("^Art=") then
        art = line:match("^Art=(.+)")
      elseif line:match("^Art:hd=") then
        hdArt = line:match("^Art:hd=(.+)")
      end
      if art then
        currentUnit['artIconPath'] = art
      end
      if hdArt then
        currentUnit['hdArtIconPath'] = hdArt
      end
      if art or hdArt then
        units[currentUnitId] = currentUnit
      end
    end
  end
  return units
end

local allUsedUnitBaseIdsFile = io.open(allUsedUnitBaseIdsPath, "r")
local outputFile = io.open(outputFilePath, "w")

if outputFile == nil then
  print("Failed to open output file for writing")
end

if allUsedUnitBaseIdsFile == nil then
  print("Failed to open allUsedUnitBaseIdsFile for reading")
  print("Running getUnitBaseIdsList.lua to generate allUsedUnitBaseIdsFile")
  dofile('getUnitBaseIdsList.lua')
end

allUsedUnitBaseIdsFile = io.open(allUsedUnitBaseIdsPath, "r")

if outputFile and allUsedUnitBaseIdsFile then
  local unitIconPaths = parseUnitFileForIconPaths("unitskin.txt")
  outputFile:write(json.encode(unitIconPaths, {indent = true}))
  outputFile:close()
else
  print("Failed to open output file for writing")
end