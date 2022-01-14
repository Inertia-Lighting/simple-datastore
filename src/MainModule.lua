----------------------------------------------------------------
--    Copyright (c) Inertia Lighting, Some Rights Reserved    --
----------------------------------------------------------------

local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

----------------------------------------------------------------

local DataStoreRouter = {}
DataStoreRouter.__index = DataStoreRouter

function DataStoreRouter.new(dataStoreName)
    local self = setmetatable({}, DataStoreRouter)

    self.name = dataStoreName
    self.dataStore = DataStoreService:GetDataStore(self.name)

    return self
end

function DataStoreRouter:get()
    return self.dataStore:GetAsync(self.name) or {}
end

function DataStoreRouter:set(value)
    if type(value) ~= "table" then error("parameter (value) must be a table") end

    return self.dataStore:SetAsync(self.name, value)
end

function DataStoreRouter:clear()
    return self:set({})
end

----------------------------------------------------------------

local CachedDataStore = {}
CachedDataStore.__index = CachedDataStore

function CachedDataStore.new(dataStoreName, saveIntervalInSeconds)
    local self = setmetatable({}, CachedDataStore)

    self.name = dataStoreName

    self.saveIntervalInSeconds = (saveIntervalInSeconds and saveIntervalInSeconds > 5) and saveIntervalInSeconds or (5 * 60)

    self._cache = {}

    self._dataStoreRouter = DataStoreRouter.new(self.name)

    self._heartbeatConnection = RunService.Heartbeat:Connect((function()
        local elapsedTimeSinceLastSaveInSeconds = 0

        return function(deltaTimeInSeconds)
            elapsedTimeSinceLastSaveInSeconds = elapsedTimeSinceLastSaveInSeconds + deltaTimeInSeconds

            if elapsedTimeSinceLastSaveInSeconds < self.saveIntervalInSeconds then return end
            elapsedTimeSinceLastSaveInSeconds = 0

            task.spawn(function()
                self:save()
            end)
        end
    end)())

    return self
end

function CachedDataStore:get(key, bypassCache)
    if (not bypassCache) and (self._cache[key] ~= nil) then
        return self._cache[key]
    end

    self._cache[key] = self._dataStoreRouter:get()[key]

    return self._cache[key]
end

function CachedDataStore:set(key, value)
    self._cache[key] = value
end

function CachedDataStore:remove(key)
    self._cache[key] = nil
end

function CachedDataStore:clear()
    table.clear(self._cache)
end

function CachedDataStore:save()
    local saveData = {}

    for key, value in pairs(self._dataStoreRouter:get()) do
        saveData[key] = value
    end

    for key, value in pairs(self._cache) do
        saveData[key] = value
    end

    self._dataStoreRouter:set(saveData)
end

function CachedDataStore:destroy()
    if not self._heartbeatConnection then return end

    self._heartbeatConnection:Disconnect()
    self._heartbeatConnection = nil

    self:clear()
end

----------------------------------------------------------------

return {
    ["DataStoreRouter"] = DataStoreRouter,
    ["CachedDataStore"] = CachedDataStore,
}
