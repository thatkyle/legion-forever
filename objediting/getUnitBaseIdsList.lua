local function readCsvColumnAndWriteToFile(inputFileName, columnName, outputFileName)
  local inputFile = io.open(inputFileName, "r") -- Open the input file for reading
  local outputFile = io.open(outputFileName, "w") -- Open the output file for writing
  local columnIndex = nil

  if not inputFile then
      print("Input file not found")
      return
  end

  if not outputFile then
      print("Failed to open output file for writing")
      if inputFile then inputFile:close() end
      return
  end

  local header = inputFile:read() -- Read the first line containing column names
  if header then
      -- Split the header to find the index of the columnName
      for index, name in ipairs(split(header, ",")) do
          if name == columnName then
              columnIndex = index
              break
          end
      end
  end

  if not columnIndex then
      print("Column not found")
      inputFile:close()
      outputFile:close()
      return
  end

  for line in inputFile:lines() do
      local valuesInLine = split(line, ",")
      if valuesInLine[columnIndex] then -- Check if the column value exists
          outputFile:write(valuesInLine[columnIndex] .. "\n")
      end
  end

  inputFile:close() -- Close the input file
  outputFile:close() -- Close the output file
end

-- Helper function to split strings by a delimiter
function split(str, delimiter)
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(str, delimiter, from)
  while delim_from do
      table.insert(result, string.sub(str, from, delim_from-1))
      from = delim_to + 1
      delim_from, delim_to = string.find(str, delimiter, from)
  end
  table.insert(result, string.sub(str, from))
  return result
end

local inputFileName = 'TeamTeamDUnitData - Sheet3.csv'
local columnName = 'BaseID'
local outputFileName = '../shared/allUnitBaseIds.txt'

readCsvColumnAndWriteToFile(inputFileName, columnName, outputFileName)