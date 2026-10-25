TrackingManager = {}

local activeJammers = {}

--- Retorna se as coordenadas informadas estão sob efeito de interferência de algum jammer ativo
function TrackingManager.IsAreaJammed(coords, maxRadius)
    local checkDist = maxRadius or 20.0
    for jammerSrc, _ in pairs(activeJammers) do
        local ped = GetPlayerPed(jammerSrc)
        if ped and ped ~= 0 then
            local jammerCoords = GetEntityCoords(ped)
            if #(coords - jammerCoords) <= checkDist then
                return true, jammerSrc
            end
        end
    end
    return false, nil
end

--- Retorna se um jogador específico possui jammer ativo
function TrackingManager.IsPlayerJammed(source)
    return activeJammers[source] ~= nil
end

--- Thread de drenagem contínua de bateria do Jammer (1% a cada 60s)
CreateThread(function()
    local drainInterval = (Config.Tracking and Config.Tracking.jammerDrainInterval) or 60
    while true do
        Wait(drainInterval * 1000)

        for src, jammerData in pairs(activeJammers) do
            if GetPlayerPing(src) <= 0 then
                activeJammers[src] = nil
            else
                local slot = jammerData.slot
                local item = exports.ox_inventory:GetSlot(src, slot)

                -- Se o item não estiver mais no slot ou não for o jammer, desliga
                if not item or item.name ~= Config.Tracking.jammerItem then
                    activeJammers[src] = nil
                    Player(src).state:set("hasJammerActive", false, true)
                else
                    local meta = item.metadata or {}
                    local currentBattery = tonumber(meta.battery) or 100
                    local newBattery = math.max(0, currentBattery - 1)

                    if newBattery <= 0 then
                        -- Bateria esgotada
                        meta.battery = 0
                        meta.is_active = false
                        meta.jammer_status = "Sem Bateria"
                        meta.description = "Bateria esgotada (0%). Substitua as baterias para reativar."
                        exports.ox_inventory:SetMetadata(src, slot, meta)

                        activeJammers[src] = nil
                        Player(src).state:set("hasJammerActive", false, true)

                        TriggerClientEvent("ox_lib:notify", src, {
                            title = "Bloqueador de Sinal",
                            description = "⚠️ A bateria do seu Bloqueador de Frequência se esgotou e o aparelho desligou!",
                            type = "error",
                            duration = 6000
                        })
                        TriggerClientEvent("haze_simcard:client:playTacticalSound", src, "jammer_off")
                    else
                        meta.battery = newBattery
                        meta.is_active = true
                        meta.jammer_status = "Ligado"
                        meta.description = string.format("Status: LIGADO | Bateria: %d%% | Ruído RF ativo em 20m.", newBattery)
                        exports.ox_inventory:SetMetadata(src, slot, meta)
                    end
                end
            end
        end
    end
end)

--- Callback de Triangulação IMSI Inicial (phone_tracker)
lib.callback.register("haze_simcard:server:trackNumber", function(source, targetNumber)
    if not source or not targetNumber then return false, "invalid_number" end

    -- Valida se o solicitante possui o item rastreador na mochila
    local trackerCount = exports.ox_inventory:GetItemCount(source, Config.Tracking.trackerItem)
    if not trackerCount or trackerCount <= 0 then
        return false, "no_item"
    end

    if not Security.CheckRateLimit(source, "track_number", 3500) then
        return false, "rate_limited"
    end

    local sim = Database.GetSimByNumber(targetNumber)
    if not sim then
        return false, "invalid_number"
    end

    local targetSrc = PhoneBridge.GetSourceFromNumber(targetNumber)
    if not targetSrc or GetPlayerPing(targetSrc) <= 0 then
        return false, "offline"
    end

    local targetPed = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then
        return false, "offline"
    end

    -- Checa se o aparelho do alvo está de fato LIGADO
    local isTurnedOn = false
    local phones = exports.ox_inventory:Search(targetSrc, "slots", Config.PhoneItem)
    if phones then
        for _, p in pairs(phones) do
            local meta = p.metadata or {}
            if tostring(meta.phone_number) == tostring(targetNumber) and meta.phone_status == "Ligado" then
                isTurnedOn = true
                break
            end
        end
    end

    if not isTurnedOn then
        return false, "offline"
    end

    local realCoords = GetEntityCoords(targetPed)

    -- Verifica se o alvo está sob efeito de interferência de Jammer (ele próprio ou num raio de 20m)
    local isJammed = TrackingManager.IsAreaJammed(realCoords, 20.0)
    if isJammed then
        return false, "jammed"
    end

    -- Se a operadora do alvo for Bittersweet Mobile, alerta o titular sobre a varredura
    if sim.operator == 'Bittersweet Mobile' then
        TriggerClientEvent("ox_lib:notify", targetSrc, {
            title = "Bittersweet Security",
            description = "🚨 [ALERTA DE SEGURANÇA] Tentativa de varredura/triangulação de sinal detectada na sua linha!",
            type = "warning",
            duration = 8000
        })
        TriggerClientEvent("haze_simcard:client:playTacticalSound", targetSrc, "intercept_alert")
    end

    -- Calcula o raio de dispersão da antena ERB
    local radius = Config.Tracking.baseRadius or 180.0
    if sim.operator == 'EyeFind Telecom' then
        -- EyeFind possui proteção corporativa que expande em +150m a margem de erro
        radius = radius + (Config.Operators['eyefind'].antiTrackerBonus or 150.0)
    end

    -- Dispersão angular aleatória da antena
    local angle = math.random() * 2 * math.pi
    local dist = math.random(25, math.floor(radius * 0.40))
    local randomizedCoords = vector3(
        realCoords.x + math.cos(angle) * dist,
        realCoords.y + math.sin(angle) * dist,
        realCoords.z
    )

    return true, {
        coords = randomizedCoords,
        radius = radius,
        duration = Config.Tracking.duration or 40,
        targetSrc = targetSrc,
        targetNumber = targetNumber,
        operator = sim.operator
    }
end)

--- Callback de Pulso Periódico de Triangulação (chamado pelo client para atualizar antena)
lib.callback.register("haze_simcard:server:pingTrackTarget", function(source, targetNumber)
    if not source or not targetNumber then return false, "invalid_number" end

    local targetSrc = PhoneBridge.GetSourceFromNumber(targetNumber)
    if not targetSrc or GetPlayerPing(targetSrc) <= 0 then
        return false, "offline"
    end

    local targetPed = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then
        return false, "offline"
    end

    -- Checa se ainda está ligado
    local isTurnedOn = false
    local phones = exports.ox_inventory:Search(targetSrc, "slots", Config.PhoneItem)
    if phones then
        for _, p in pairs(phones) do
            local meta = p.metadata or {}
            if tostring(meta.phone_number) == tostring(targetNumber) and meta.phone_status == "Ligado" then
                isTurnedOn = true
                break
            end
        end
    end

    if not isTurnedOn then
        return false, "offline"
    end

    local realCoords = GetEntityCoords(targetPed)
    if TrackingManager.IsAreaJammed(realCoords, 20.0) then
        return false, "jammed"
    end

    local sim = Database.GetSimByNumber(targetNumber)
    local radius = Config.Tracking.baseRadius or 180.0
    if sim and sim.operator == 'EyeFind Telecom' then
        radius = radius + (Config.Operators['eyefind'].antiTrackerBonus or 150.0)
    end

    local angle = math.random() * 2 * math.pi
    local dist = math.random(25, math.floor(radius * 0.40))
    local randomizedCoords = vector3(
        realCoords.x + math.cos(angle) * dist,
        realCoords.y + math.sin(angle) * dist,
        realCoords.z
    )

    return true, {
        coords = randomizedCoords,
        radius = radius
    }
end)

--- Alternar Energia do Jammer de Frequência
RegisterNetEvent("haze_simcard:server:toggleJammer", function(slot)
    local source = source
    if not Security.CheckRateLimit(source, "toggle_jammer", 1500) then return end

    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or item.name ~= Config.Tracking.jammerItem then return end

    local meta = item.metadata or {}
    local currentBattery = tonumber(meta.battery) or 100

    local isCurrentlyActive = activeJammers[source] ~= nil

    if isCurrentlyActive then
        -- Desligar jammer
        activeJammers[source] = nil
        Player(source).state:set("hasJammerActive", false, true)

        meta.is_active = false
        meta.jammer_status = "Desligado"
        meta.battery = currentBattery
        meta.description = string.format("Status: DESLIGADO | Bateria: %d%%.", currentBattery)
        exports.ox_inventory:SetMetadata(source, slot, meta)

        TriggerClientEvent("ox_lib:notify", source, {
            title = "Bloqueador de Sinal",
            description = string.format("Bloqueador DESLIGADO. Bateria restante: %d%%.", currentBattery),
            type = "inform"
        })
        TriggerClientEvent("haze_simcard:client:playTacticalSound", source, "jammer_off")
    else
        -- Tentar ligar jammer
        if currentBattery <= 0 then
            TriggerClientEvent("ox_lib:notify", source, {
                title = "Bloqueador de Sinal",
                description = "Bateria esgotada (0%). O aparelho não tem carga para operar.",
                type = "error"
            })
            return
        end

        activeJammers[source] = {
            slot = slot,
            battery = currentBattery
        }
        Player(source).state:set("hasJammerActive", true, true)

        meta.is_active = true
        meta.jammer_status = "Ligado"
        meta.battery = currentBattery
        meta.description = string.format("Status: LIGADO | Bateria: %d%% | Ruído RF ativo em 20m.", currentBattery)
        exports.ox_inventory:SetMetadata(source, slot, meta)

        TriggerClientEvent("ox_lib:notify", source, {
            title = "Bloqueador de Sinal",
            description = string.format("Bloqueador LIGADO. Frequência blindada | Bateria: %d%%.", currentBattery),
            type = "success"
        })
        TriggerClientEvent("haze_simcard:client:playTacticalSound", source, "jammer_on")
    end
end)

--- Recarga de Bateria do Jammer (para lojas clandestinas ou itens)
RegisterNetEvent("haze_simcard:server:rechargeJammer", function(slot)
    local source = source
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or item.name ~= Config.Tracking.jammerItem then return end

    local meta = item.metadata or {}
    meta.battery = 100
    meta.description = string.format("Status: %s | Bateria: 100%%.", meta.is_active and "LIGADO" or "DESLIGADO")
    exports.ox_inventory:SetMetadata(source, slot, meta)

    if activeJammers[source] then
        activeJammers[source].battery = 100
    end

    TriggerClientEvent("ox_lib:notify", source, {
        title = "Bloqueador de Sinal",
        description = "Bateria do Bloqueador totalmente recarregada (100%).",
        type = "success"
    })
end)

AddEventHandler("playerDropped", function()
    local src = source
    activeJammers[src] = nil
end)
