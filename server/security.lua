Security = {}

local rateLimits = {}

--- Valida se uma ação está respeitando o rate limit mínimo
---@param source number
---@param action string
---@param minDelayMs number?
---@return boolean
function Security.CheckRateLimit(source, action, minDelayMs)
    minDelayMs = minDelayMs or 1500
    local key = string.format("%s:%s", source, action)
    local now = GetGameTimer()

    if rateLimits[key] and (now - rateLimits[key]) < minDelayMs then
        return false
    end

    rateLimits[key] = now
    return true
end

AddEventHandler("playerDropped", function()
    local src = source
    for key, _ in pairs(rateLimits) do
        if key:find("^" .. src .. ":") then
            rateLimits[key] = nil
        end
    end
end)

--- Valida a proximidade física do jogador com um ponto de interesse
---@param source number
---@param coords vector3|vector4
---@param maxDist number?
---@return boolean
function Security.ValidateDistance(source, coords, maxDist)
    if not source or not coords then return false end
    maxDist = maxDist or 4.0
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)
    local targetVec = vector3(coords.x, coords.y, coords.z)
    local dist = #(pCoords - targetVec)
    return dist <= maxDist
end

--- Retorna o objeto do jogador QBox
---@param source number
---@return table|nil
function Security.GetPlayer(source)
    if exports.qbx_core and exports.qbx_core.GetPlayer then
        return exports.qbx_core:GetPlayer(source)
    end
    return nil
end

--- Retorna o CitizenID / Identificador único do personagem
---@param source number
---@return string|nil
function Security.GetCitizenId(source)
    local player = Security.GetPlayer(source)
    return player and player.PlayerData.citizenid or nil
end

--- Retorna o nome completo do personagem
---@param source number
---@return string
function Security.GetCharacterName(source)
    local player = Security.GetPlayer(source)
    if player and player.PlayerData.charinfo then
        local first = player.PlayerData.charinfo.firstname or ""
        local last = player.PlayerData.charinfo.lastname or ""
        return (first .. " " .. last):gsub("^%s*(.-)%s*$", "%1")
    end
    return GetPlayerName(source)
end

--- Verifica se o jogador possui saldo suficiente
---@param source number
---@param amount number
---@param accountType string?
---@return boolean, string?
function Security.HasMoney(source, amount, accountType)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true, "free" end

    local cashCount = exports.ox_inventory:GetItemCount(source, 'money') or 0
    local player = Security.GetPlayer(source)
    local bankBalance = (player and player.PlayerData.money.bank) or 0

    accountType = accountType or Config.Account or 'both'

    if accountType == 'money' then
        return cashCount >= amount, 'money'
    elseif accountType == 'bank' then
        return bankBalance >= amount, 'bank'
    else -- 'both'
        if cashCount >= amount then
            return true, 'money'
        elseif bankBalance >= amount then
            return true, 'bank'
        end
    end

    return false, nil
end

--- Remove dinheiro do jogador priorizando dinheiro físico ou banco
---@param source number
---@param amount number
---@param accountType string?
---@return boolean
function Security.RemoveMoney(source, amount, accountType)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end

    local hasBalance, method = Security.HasMoney(source, amount, accountType)
    if not hasBalance then return false end

    if method == 'money' then
        return exports.ox_inventory:RemoveItem(source, 'money', amount)
    elseif method == 'bank' then
        local player = Security.GetPlayer(source)
        if player and player.Functions and player.Functions.RemoveMoney then
            return player.Functions.RemoveMoney('bank', amount, 'haze_simcard_purchase')
        end
    end

    return false
end

--- Verifica se o jogador possui um cargo policial autorizado e em serviço
---@param source number
---@return boolean
function Security.IsPolice(source)
    local player = Security.GetPlayer(source)
    if not player or not player.PlayerData.job then return false end

    local jobData = player.PlayerData.job
    local jobName = jobData.name
    local minGrade = Config.PoliceJobs[jobName]

    if minGrade == nil then return false end

    -- Policiais à paisana (fora de serviço) não possuem acesso
    if jobData.onduty == false then
        return false
    end

    local gradeLevel = (jobData.grade and jobData.grade.level) or 0
    return gradeLevel >= minGrade
end

--- Valida se o jogador está a uma distância segura de qualquer loja registrada
---@param source number
---@param maxDist number?
---@return boolean
function Security.ValidateShopDistance(source, maxDist)
    maxDist = maxDist or 5.0
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)

    for _, shop in ipairs(Config.Shops or {}) do
        local sCoords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
        if #(pCoords - sCoords) <= maxDist then
            return true
        end
    end

    return false
end

--- Valida se o policial está autorizado e em local apto para consulta investigativa
---@param source number
---@return boolean, string
function Security.ValidatePoliceAccess(source)
    if not Security.IsPolice(source) then
        return false, "Acesso negado: Você não é um agente de segurança pública em serviço."
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, "Jogador inválido." end
    local pCoords = GetEntityCoords(ped)

    -- 1. Verifica proximidade com Terminais em Delegacias
    for _, term in ipairs(Config.PoliceTerminals or {}) do
        if #(pCoords - term.coords) <= 5.0 then
            return true, "terminal"
        end
    end

    -- 2. Verifica proximidade com Lojas Oficiais de Telecomunicações
    for _, shop in ipairs(Config.Shops or {}) do
        if not shop.allowBurner then
            local sCoords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
            if #(pCoords - sCoords) <= 5.0 then
                return true, "shop"
            end
        end
    end

    -- 3. Verifica se o policial está dentro de uma viatura policial (MDT de bordo)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        local vehClass = GetVehicleClass(veh)
        if vehClass == 18 then -- 18 = Emergency
            return true, "mdt"
        end
    end

    return false, "Você precisa estar em uma delegacia, loja oficial ou viatura para acessar o terminal policial."
end

--- Registra logs de auditoria e segurança
---@param tag string
---@param message string
function Security.Log(tag, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("^3[haze_simcard]^7 [^4%s^7] [%s] %s", timestamp, tag, message))
end
