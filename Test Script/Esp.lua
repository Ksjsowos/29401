-- Optimized Esp.lua (постоянно работающий ESP)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Конфигурация
local CONFIG = {
    ESP_NAME = "ExternalPlayerESP",
    GUI_SIZE = UDim2.new(0, 120, 0, 40),
    STUDS_OFFSET = Vector3.new(0, 3.5, 0),
    MAX_DISTANCE = 1500,
    TEXT_SIZE = 14,
    TEXT_STROKE_TRANSPARENCY = 0.5,
    UPDATE_INTERVAL = 0.1, -- Интервал обновления в секундах
    COLOR_NORMAL = Color3.fromRGB(255, 255, 255),
    COLOR_REVIVES = Color3.fromRGB(255, 255, 0),
    COLOR_DOWNED = Color3.fromRGB(255, 0, 0)
}

-- Глобальные переменные
_G.ExternalESPRunning = true
local ESPInstances = {}
local ESPConnection = nil
local lastUpdateTime = 0

-- Функция для полного удаления ESP
_G.StopExternalESP = function()
    _G.ExternalESPRunning = false
    
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    
    -- Быстрое удаление всех ESP
    for _, esp in pairs(ESPInstances) do
        if esp and esp.Parent then
            esp:Destroy()
        end
    end
    table.clear(ESPInstances)
    
    print("[External ESP] Stopped")
end

-- Создание ESP для игрока
local function createESP(player)
    if not _G.ExternalESPRunning or player == LocalPlayer then return end
    
    local character = player.Character
    if not character then return end
    
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end
    
    -- Удаление существующего ESP
    local existingESP = ESPInstances[player]
    if existingESP and existingESP.Parent then
        existingESP:Destroy()
    end
    
    -- Создаем BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = CONFIG.ESP_NAME
    billboard.Adornee = head
    billboard.Size = CONFIG.GUI_SIZE
    billboard.StudsOffset = CONFIG.STUDS_OFFSET
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = CONFIG.MAX_DISTANCE
    billboard.Active = true
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Текст
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = CONFIG.COLOR_NORMAL
    textLabel.TextSize = CONFIG.TEXT_SIZE
    textLabel.Font = Enum.Font.RobotoMono
    textLabel.TextStrokeTransparency = CONFIG.TEXT_STROKE_TRANSPARENCY
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    
    -- Устанавливаем родитель после настройки всех параметров (оптимизация)
    textLabel.Parent = billboard
    billboard.Parent = head
    
    ESPInstances[player] = billboard
    
    -- Устанавливаем начальный текст
    local humanoidRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local distance = humanoidRootPart and (head.Position - humanoidRootPart.Position).Magnitude or 0
    textLabel.Text = string.format("%s [%dm]", player.Name, math.floor(distance))
    
    return billboard
end

-- Обновление всех ESP
local function updateAllESP()
    -- Ограничение частоты обновления
    local currentTime = tick()
    if currentTime - lastUpdateTime < CONFIG.UPDATE_INTERVAL then
        return
    end
    lastUpdateTime = currentTime
    
    if not _G.ExternalESPRunning then return end
    
    local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end
    
    -- Локальные переменные для оптимизации
    local espInstances = ESPInstances
    local players = Players:GetPlayers()
    
    -- Обновляем существующие ESP
    for i = #players, 1, -1 do -- Обратный цикл для эффективности
        local player = players[i]
        if player ~= LocalPlayer then
            local esp = espInstances[player]
            if esp and esp.Parent then
                local character = player.Character
                if character then
                    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
                    local textLabel = esp:FindFirstChildOfClass("TextLabel")
                    
                    if head and textLabel then
                        -- Расстояние
                        local distance = (head.Position - localHRP.Position).Magnitude
                        
                        -- Цвет и текст в зависимости от состояния
                        local textColor = CONFIG.COLOR_NORMAL
                        local extraText = ""
                        
                        if character:FindFirstChild("Revives") then
                            textColor = CONFIG.COLOR_REVIVES
                            extraText = "] [Revives"
                        elseif character:GetAttribute("Downed") then
                            textColor = CONFIG.COLOR_DOWNED
                            extraText = "] [Downed"
                        end
                        
                        textLabel.Text = string.format("%s [%dm%s]", player.Name, math.floor(distance), extraText)
                        textLabel.TextColor3 = textColor
                    end
                else
                    -- Удаляем невалидные ESP
                    esp:Destroy()
                    espInstances[player] = nil
                end
            end
        end
    end
    
    -- Проверяем новых игроков
    for i = #players, 1, -1 do
        local player = players[i]
        if player ~= LocalPlayer and not espInstances[player] and player.Character then
            createESP(player)
        end
    end
end

-- Инициализация ESP для всех игроков
local function initializePlayerESP(player)
    if player ~= LocalPlayer and player.Character then
        createESP(player)
    end
    
    -- Ожидание появления персонажа
    player.CharacterAdded:Connect(function(character)
        task.delay(0.5, function()
            if _G.ExternalESPRunning then
                createESP(player)
            end
        end)
    end)
end

-- Инициализация для существующих игроков
for _, player in ipairs(Players:GetPlayers()) do
    initializePlayerESP(player)
end

-- Подключение для новых игроков
Players.PlayerAdded:Connect(initializePlayerESP)

-- Очистка при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    local esp = ESPInstances[player]
    if esp then
        esp:Destroy()
        ESPInstances[player] = nil
    end
end)

-- Главный loop для обновления ESP
ESPConnection = RunService.Heartbeat:Connect(updateAllESP)

-- Автоматическое восстановление при респавне локального игрока
LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        if _G.ExternalESPRunning then
            -- Пересоздаем ESP для всех игроков
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    createESP(player)
                end
            end
        end
    end)
end)

print("[External ESP] Loaded and running")
return _G.StopExternalESP