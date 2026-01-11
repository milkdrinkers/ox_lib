--[[
    Based on PolyZone's grid system (https://github.com/mkafrin/PolyZone/blob/master/ComboZone.lua)

    MIT License

    Copyright © 2019-2021 Michael Afrin

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

local mapMinX = -3700
local mapMinY = -4400
local mapMaxX = 4500
local mapMaxY = 8000
local xDelta = (mapMaxX - mapMinX) / 34
local yDelta = (mapMaxY - mapMinY) / 50
local grid = {}
local lastCell = {}
local gridCache = {}
local entrySet = {}

lib.grid = {}

---@class GridEntry
---@field coords vector
---@field length? number
---@field width? number
---@field radius? number
---@field [string] any

---@param point vector
---@param length number
---@param width number
---@return number, number, number, number
local function getGridDimensions(point, length, width)
    local minX = (point.x - width - mapMinX) // xDelta
    local maxX = (point.x + width - mapMinX) // xDelta
    local minY = (point.y - length - mapMinY) // yDelta
    local maxY = (point.y + length - mapMinY) // yDelta

    return minX, maxX, minY, maxY
end

---@param point vector
---@return number, number
function lib.grid.getCellPosition(point)
    local x = (point.x - mapMinX) // xDelta
    local y = (point.y - mapMinY) // yDelta

    return x, y
end

---@param point vector
---@param range? integer Range in cells (defaults to 1 = 3x3 grid, 2 = 5x5 grid, etc.)
---@return table<vector2>
function lib.grid.getCellPositions(point, range)
    range = range or 1

    local searchLength = yDelta * range
    local searchWidth = xDelta * range
    
    local minX, maxX, minY, maxY = getGridDimensions(point, searchLength, searchWidth)
    
    local cellPositions = {}
    
    local cellsX = maxX - minX + 1
    local cellsY = maxY - minY + 1
    local totalCells = cellsX * cellsY
    
    for i = 0, totalCells - 1 do
        local offsetX = i % cellsX
        local offsetY = i // cellsX
        
        local x = minX + offsetX
        local y = minY + offsetY
        
        cellPositions[i + 1] = vector2(x, y)
    end
    
    return cellPositions
end

---@param point vector
---@return GridEntry[]
function lib.grid.getCell(point)
    local x, y = lib.grid.getCellPosition(point)

    if lastCell.x ~= x or lastCell.y ~= y then
        lastCell.x = x
        lastCell.y = y
        lastCell.cell = grid[y] and grid[y][x] or {}
    end

    return lastCell.cell
end

---@param point vector
---@param filter? fun(entry: GridEntry): boolean
---@param range? integer Range in cells (defaults to 1 = 3x3 grid, 2 = 5x5 grid, etc.)
---@return Array<GridEntry>
function lib.grid.getNearbyEntries(point, filter, range)
    if gridCache.filter == filter and
        gridCache.range == range and
        gridCache.point == point then
        return gridCache.entries
    end

    local cellPositions = lib.grid.getCellPositions(point, range)

    local entries = lib.array:new()
    local n = 0
    table.wipe(entrySet)

    for i = 1, #cellPositions do
        local cellPos = cellPositions[i]
        local x, y = cellPos.x, cellPos.y
        
        local row = grid[y]
        local cell = row and row[x]
        
        if cell then
            for j = 1, #cell do
                local entry = cell[j]
                
                if not entrySet[entry] and (not filter or filter(entry)) then
                    n = n + 1
                    entrySet[entry] = true
                    entries[n] = entry
                end
            end
        end
    end

    gridCache.point = point
    gridCache.range = range
    gridCache.entries = entries
    gridCache.filter = filter

    return entries
end

---@param entry { coords: vector, length?: number, width?: number, radius?: number, [string]: any }
function lib.grid.addEntry(entry)
    entry.length = entry.length or entry.radius * 2
    entry.width = entry.width or entry.radius * 2
    local minX, maxX, minY, maxY = getGridDimensions(entry.coords, entry.length, entry.width)

    for y = minY, maxY do
        local row = grid[y] or {}

        for x = minX, maxX do
            local cell = row[x] or {}

            cell[#cell + 1] = entry
            row[x] = cell
        end

        grid[y] = row

        table.wipe(gridCache)
    end
end

---@param entry { coords: vector, length: number, width: number } A table that was added to the grid previously.
function lib.grid.removeEntry(entry)
    local minX, maxX, minY, maxY = getGridDimensions(entry.coords, entry.length, entry.width)
    local success = false

    for y = minY, maxY do
        local row = grid[y]

        if not row then goto continue end

        for x = minX, maxX do
            local cell = row[x]

            if cell then
                for i = 1, #cell do
                    if cell[i] == entry then
                        table.remove(cell, i)
                        success = true
                        break
                    end
                end

                if #cell == 0 then
                    row[x] = nil
                end
            end
        end

        if not next(row) then
            grid[y] = nil
        end

        ::continue::
    end

    table.wipe(gridCache)

    return success
end

return lib.grid
