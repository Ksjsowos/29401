-- Optimized NextbotESP.lua
-- Оптимизированный внешний файл для Nextbot ESP из Draconic Hub

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Конфигурация
local CONFIG = {
    ESP_NAME = "NextbotESP",
    GUI_SIZE = UDim2.new(0, 200, 0, 50),
    STUDS_OFFSET = Vector3.new(0, 3, 0),
    MAX_DISTANCE = 1000,
    TEXT_SIZE = 16,
    FAKE_PART_NAME = "ESP_Anchor",
    COLOR = Color3.fromRGB(255, 0, 0),
    SCAN_INTERVAL = 0.1, -- Интервал сканирования в секундах
    MAX_STALE_TIME = 10, -- Максимальное время жизни ESP в секундах
    BATCH_SIZE = 10 -- Количество некстботов для обработки за один цикл
}

-- Глобальные переменные
_G.NextbotESPRunning = false
local NextbotBillboards = {}
local nextbotLoop = nil
local lastScanTime = 0
local scanQueue = {}
local queueIndex = 1

-- Глобальные функции для управления
_G.StopNextbotESP = function()
    _G.NextbotESPRunning = false
    if nextbotLoop then
        nextbotLoop:Disconnect()
        nextbotLoop = nil
    end
    clearAllNextbotESP()
end

-- Получение имен Nextbot из ReplicatedStorage
local nextBotNames = {}
do
    local npcs = ReplicatedStorage:FindFirstChild("NPCs")
    if npcs then
        for _, npc in ipairs(npcs:GetChildren()) do
            table.insert(nextBotNames, npc.Name)
        end
    end
end

-- Проверка, является ли модель Nextbot
local function isNextbotModel(model)
    if not model or not model.Name then 
        return false 
    end
    
    -- Проверка по списку известных имен
    for _, name in ipairs(nextBotNames) do
        if model.Name == name then 
            return true 
        end
    end
    
    -- Проверка по ключевым словам (оптимизировано через локальные переменные)
    local lowerName = model.Name:lower()
    
    return lowerName:find("nextbot") or 
           lowerName:find("scp%-") or 
           lowerName:find("^monster") or 
           lowerName:find("^creep") or 
           lowerName:find("^enemy") or 
           model:GetAttribute("IsNPC") or 
           model:GetAttribute("Nextbot") and 
           not Players:FindFirstChild(model.Name)
end

-- Получение расстояния от игрока
local function getDistanceFromPlayer(targetPosition)
    local character = LocalPlayer.Character
    if not character then return 0 end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    
    return math.floor((targetPosition - hrp.Position).Magnitude)
end

-- ==================== ОПТИМИЗИРОВАННЫЕ ФУНКЦИИ ESP ====================

-- Создание Billboard ESP
local function CreateBillboardESP(part)
    if not part then return nil end
    
    -- Проверка существующего ESP
    local existingESP = part:FindFirstChild(CONFIG.ESP_NAME)
    if existingESP then
        return existingESP
    end

    -- Создание GUI с оптимизированной последовательностью
    local billboard = Instance.new("BillboardGui")
    billboard.Name = CONFIG.ESP_NAME
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 1
    billboard.Size = CONFIG.GUI_SIZE
    billboard.StudsOffset = CONFIG.STUDS_OFFSET
    billboard.MaxDistance = CONFIG.MAX_DISTANCE
    
    -- Установка Parent после настройки всех параметров
    billboard.Parent = part

    -- Создание TextLabel
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextScaled = false
    label.Font = Enum.Font.RobotoMono
    label.TextStrokeTransparency = 0.5
    label.TextSize = CONFIG.TEXT_SIZE
    label.TextColor3 = CONFIG.COLOR
    label.Text = "Loading..."
    
    -- Установка Parent после настройки
    label.Parent = billboard

    return billboard
end

-- Обновление Billboard ESP
local function UpdateBillboardESP(part, modelName, extraText)
    if not part then return false end

    local esp = part:FindFirstChild(CONFIG.ESP_NAME)
    if esp then
        local label = esp:FindFirstChildOfClass("TextLabel")
        if label then
            local distance = getDistanceFromPlayer(part.Position)
            label.Text = string.format("%s [%d m%s]", modelName, distance, extraText or "")
            return true
        end
    end
    return false
end

-- Уничтожение Billboard ESP
local function DestroyBillboardESP(part)
    if not part then return false end
    
    local esp = part:FindFirstChild(CONFIG.ESP_NAME)
    if esp then
        esp:Destroy()
        return true
    end
    
    return false
end

-- Создание fake part для модели
local function createFakePartForModel(model)
    if not model or not model:IsA("Model") then return nil end
    
    local fakePart = Instance.new("Part")
    fakePart.Name = CONFIG.FAKE_PART_NAME
    fakePart.Size = Vector3.new(0.1, 0.1, 0.1)
    fakePart.Transparency = 1
    fakePart.CanCollide = false
    fakePart.Anchored = true
    fakePart.Parent = model
    
    -- Позиционирование fake part
    local primaryPart = model.PrimaryPart
    if primaryPart then
        fakePart.CFrame = primaryPart.CFrame
    else
        local success, center = pcall(function()
            return model:GetBoundingBox()
        end)
        if success and center then
            fakePart.CFrame = center
        else
            local firstPart = model:FindFirstChildWhichIsA("BasePart")
            if firstPart then
                fakePart.CFrame = firstPart.CFrame
            end
        end
    end
    
    return fakePart
end

-- Добавление модели в очередь сканирования
local function addToScanQueue(model)
    scanQueue[#scanQueue + 1] = model
end

-- Обработка очереди сканирования (пакетная обработка)
local function processScanQueue()
    local batchSize = CONFIG.BATCH_SIZE
    local processed = 0
    
    while processed < batchSize and queueIndex <= #scanQueue do
        local model = scanQueue[queueIndex]
        queueIndex += 1
        
        if model and model.Parent and isNextbotModel(model) then
            -- Обработка модели
            local data = NextbotBillboards[model]
            local fakePart = model:FindFirstChild(CONFIG.FAKE_PART_NAME)
            
            if not data then
                -- Создание нового ESP
                if not fakePart then
                    fakePart = createFakePartForModel(model)
                end
                
                if fakePart then
                    local esp = CreateBillboardESP(fakePart)
                    if esp then
                        UpdateBillboardESP(fakePart, model.Name)
                        NextbotBillboards[model] = {
                            esp = esp, 
                            part = fakePart, 
                            fakePart = true,
                            lastUpdate = tick()
                        }
                    end
                end
            else
                -- Обновление существующего ESP
                if fakePart and fakePart.Parent == model then
                    -- Обновление позиции
                    local primaryPart = model.PrimaryPart
                    if primaryPart then
                        fakePart.CFrame = primaryPart.CFrame
                    else
                        local success, center = pcall(function()
                            return model:GetBoundingBox()
                        end)
                        if success and center then
                            fakePart.CFrame = center
                        end
                    end
                    
                    -- Обновление текста
                    UpdateBillboardESP(fakePart, model.Name)
                    data.lastUpdate = tick()
                else
                    -- Восстановление после удаления fake part
                    fakePart = createFakePartForModel(model)
                    if fakePart then
                        data.part = fakePart
                        local esp = CreateBillboardESP(fakePart)
                        if esp then
                            UpdateBillboardESP(fakePart, model.Name)
                            data.esp = esp
                            data.lastUpdate = tick()
                        end
                    end
                end
            end
        end
        
        processed += 1
    end
    
    -- Сброс очереди при завершении
    if queueIndex > #scanQueue then
        scanQueue = {}
        queueIndex = 1
    end
end

-- Очистка удаленных некстботов
local function cleanupRemovedNextbots()
    local currentTime = tick()
    local modelsToRemove = {}
    
    -- Сбор моделей для удаления
    for model, data in pairs(NextbotBillboards) do
        if not model.Parent or currentTime - data.lastUpdate > CONFIG.MAX_STALE_TIME then
            modelsToRemove[#modelsToRemove + 1] = model
        end
    end
    
    -- Массовое удаление
    for _, model in ipairs(modelsToRemove) do
        local data = NextbotBillboards[model]
        if data and data.part then
            DestroyBillboardESP(data.part)
            if data.fakePart then
                data.part:Destroy()
            end
        end
        NextbotBillboards[model] = nil
    end
end

-- Основная функция сканирования некстботов (оптимизированная)
local function scanForNextbots()
    local currentTime = tick()
    
    -- Ограничение частоты сканирования
    if currentTime - lastScanTime < CONFIG.SCAN_INTERVAL then
        return
    end
    lastScanTime = currentTime
    
    -- Очистка удаленных некстботов
    cleanupRemovedNextbots()
    
    -- Сбор всех потенциальных некстботов
    scanQueue = {}
    
    -- Поиск в Game.Players
    local playersFolder = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Players")
    if playersFolder then
        for _, model in ipairs(playersFolder:GetChildren()) do
            if model:IsA("Model") then
                addToScanQueue(model)
            end
        end
    end
    
    -- Поиск в NPCs
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, model in ipairs(npcsFolder:GetChildren()) do
            if model:IsA("Model") then
                addToScanQueue(model)
            end
        end
    end
    
    -- Инициализация обработки очереди
    queueIndex = 1
    
    -- Немедленная обработка первой партии
    processScanQueue()
end

-- ==================== CLEAR ESP FUNCTIONS ====================
local function clearAllNextbotESP()
    for model, data in pairs(NextbotBillboards) do
        if data.part then
            DestroyBillboardESP(data.part)
            if data.fakePart then
                data.part:Destroy()
            end
        end
    end
    NextbotBillboards = {}
end

-- Функция для запуска ESP
local function startNextbotESP()
    if nextbotLoop then return end
    
    _G.NextbotESPRunning = true
    
    nextbotLoop = RunService.Heartbeat:Connect(function()
        if _G.NextbotESPRunning then
            scanForNextbots()
            -- Продолжение обработки очереди при необходимости
            if #scanQueue > 0 and queueIndex <= #scanQueue then
                processScanQueue()
            end
        end
    end)
    
    -- Немедленно запускаем сканирование
    task.spawn(function()
        for i = 1, 3 do
            scanForNextbots()
            task.wait(0.1)
        end
    end)
    
    return true
end

-- Экспортируемые функции
return {
    Start = startNextbotESP,
    Stop = _G.StopNextbotESP,
    ClearAll = clearAllNextbotESP,
    IsRunning = function()
        return _G.NextbotESPRunning == true
    end
}