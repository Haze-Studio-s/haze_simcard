-- Registra exibição formatada de metadados no inventário
SetTimeout(1000, function()
    if exports.ox_inventory and exports.ox_inventory.displayMetadata then
        exports.ox_inventory:displayMetadata({
            formatted_number = "Número",
            sim_operator = "Operadora",
            phone_status = "Status",
            operator = "Operadora",
            formatsimnumber = "Número SIM",
            battery = "Bateria",
            jammer_status = "Jammer"
        })
    end
end)

--- Hook inteligente de transferência de celular e jammer no ox_inventory
exports.ox_inventory:registerHook("swapItems", function(payload)
    local fromSlot = payload.fromSlot
    if not fromSlot then return true end

    local fromInv = payload.fromInventory
    local toInv = payload.toInventory

    -- Se o item for o bloqueador de sinal e for transferido para fora da mochila, desliga-o
    if fromSlot.name == Config.Tracking.jammerItem then
        if fromInv ~= toInv and type(fromInv) == "number" then
            if TrackingManager and TrackingManager.IsPlayerJammed(fromInv) then
                Player(fromInv).state:set("hasJammerActive", false, true)
            end
        end
        return true
    end

    if fromSlot.name ~= Config.PhoneItem then
        return true
    end

    local meta = fromSlot.metadata or {}
    local isTurnedOn = meta.phone_status == "Ligado"
    local phoneNumber = meta.phone_number

    -- Se o inventário de origem e destino forem os mesmos (apenas mudou de slot na mochila), não altera nada
    if fromInv == toInv then
        return true
    end

    -- Se o celular não possui chip ou não estava ligado, nada a fazer
    if not phoneNumber or phoneNumber == 0 or not isTurnedOn then
        return true
    end

    -- CENÁRIO 1: Destino é outro jogador conectado (P2P / Revista / Roubo)
    if type(toInv) == "number" or (type(toInv) == "string" and tonumber(toInv) and GetPlayerPing(tonumber(toInv)) > 0) then
        local targetSrc = tonumber(toInv)
        -- Mantém o aparelho LIGADO e migra a rota da chamada imediatamente para o novo portador!
        PhoneBridge.SetPhoneNumber(targetSrc, phoneNumber)
        return true
    end

    -- CENÁRIO 2: Destino é armazenamento (baú, porta-luvas, porta-malas, lixeira ou chão)
    -- O telefone DEVE desligar para não tocar no vácuo
    CreateThread(function()
        Wait(250)
        local toInvId = payload.dropId or payload.toInventory
        local toSlotNum = payload.toSlot
        meta.phone_status = "Desligado"
        exports.ox_inventory:SetMetadata(toInvId, toSlotNum, meta)

        -- Libera a rota da conexão antiga
        if type(fromInv) == "number" then
            PhoneBridge.SetPhoneNumber(fromInv, nil)
        end
    end)

    return true
end, {
    itemFilter = {
        [Config.PhoneItem] = true,
        [Config.Tracking.jammerItem] = true
    }
})

--- Ligar / Desligar Aparelho Celular
RegisterNetEvent("haze_simcard:server:togglePower", function(slot)
    local source = source
    if not Security.CheckRateLimit(source, "toggle_power", 1500) then return end

    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or item.name ~= Config.PhoneItem then return end

    local meta = item.metadata or {}

    if meta.phone_status == "Ligado" then
        -- Desligar celular
        meta.phone_status = "Desligado"
        exports.ox_inventory:SetMetadata(source, slot, meta)
        PhoneBridge.SetPhoneNumber(source, nil)
        PhoneBridge.ClosePhone(source)
        TriggerClientEvent("ox_lib:notify", source, {
            title = "Celular",
            description = "Celular desligado.",
            type = "inform"
        })
    else
        -- Ligar celular
        if not meta.has_sim or not meta.phone_number or meta.phone_number == 0 then
            TriggerClientEvent("ox_lib:notify", source, {
                title = "Celular",
                description = "Nenhum chip SIM inserido. Insira um chip para ligar.",
                type = "error"
            })
            return
        end

        -- Verifica se o chip do celular é burner e expirou
        if meta.is_burner and BurnerManager.IsExpired(meta) then
            meta.has_sim = false
            meta.phone_number = 0
            meta.formatted_number = "Sem Chip"
            meta.phone_status = "Desligado"
            exports.ox_inventory:SetMetadata(source, slot, meta)
            TriggerClientEvent("ox_lib:notify", source, {
                title = "AnonSIM Descartável",
                description = "⚠️ O chip descartável expirou após 24h e foi destruído.",
                type = "error"
            })
            return
        end

        -- Desliga outros celulares do jogador que possam estar ligados (limite de 1 ativo por vez)
        local allPhones = exports.ox_inventory:Search(source, "slots", Config.PhoneItem)
        if allPhones then
            for _, otherPhone in pairs(allPhones) do
                if otherPhone.slot ~= slot and otherPhone.metadata and otherPhone.metadata.phone_status == "Ligado" then
                    otherPhone.metadata.phone_status = "Desligado"
                    otherPhone.metadata.hazePhoneNumber = nil
                    otherPhone.metadata.lbPhoneNumber = nil
                    exports.ox_inventory:SetMetadata(source, otherPhone.slot, otherPhone.metadata)
                end
            end
        end

        -- Liga o aparelho e ativa a rota
        meta.phone_status = "Ligado"
        meta.hazePhoneNumber = tostring(meta.phone_number)
        meta.lbPhoneNumber = tostring(meta.phone_number)
        exports.ox_inventory:SetMetadata(source, slot, meta)
        PhoneBridge.SetPhoneNumber(source, meta.phone_number)
        TriggerClientEvent("ox_lib:notify", source, {
            title = "Celular",
            description = string.format("Celular ligado. Linha ativa: %s (%s)", meta.formatted_number or meta.phone_number, meta.sim_operator or "Operadora"),
            type = "success"
        })
    end
end)

--- Inserir Chip SIM no Aparelho
RegisterNetEvent("haze_simcard:server:insertSim", function(phoneSlot, simSlot)
    local source = source
    if not Security.CheckRateLimit(source, "insert_sim", 1500) then return end

    local phoneItem = exports.ox_inventory:GetSlot(source, phoneSlot)
    local simItem = exports.ox_inventory:GetSlot(source, simSlot)

    if not phoneItem or phoneItem.name ~= Config.PhoneItem then return end
    if not simItem or not simItem.name:find("^sim_") then return end

    local phoneMeta = phoneItem.metadata or {}
    local simMeta = simItem.metadata or {}

    if phoneMeta.has_sim and phoneMeta.phone_number and phoneMeta.phone_number ~= 0 then
        TriggerClientEvent("ox_lib:notify", source, {
            title = "Celular",
            description = "O aparelho já possui um chip SIM inserido.",
            type = "error"
        })
        return
    end

    if simMeta.is_burner and BurnerManager.IsExpired(simMeta) then
        BurnerManager.BurnItem(source, simSlot)
        TriggerClientEvent("ox_lib:notify", source, {
            title = "AnonSIM Descartável",
            description = "⚠️ Este chip já estava expirado e foi destruído.",
            type = "error"
        })
        return
    end

    local simNumber = simMeta.phone_number or simMeta.simnumber
    if not simNumber then
        TriggerClientEvent("ox_lib:notify", source, {
            title = "Chip SIM",
            description = "Chip inválido ou ilegível.",
            type = "error"
        })
        return
    end

    -- Remove o chip do inventário
    local removed = exports.ox_inventory:RemoveItem(source, simItem.name, 1, nil, simSlot)
    if not removed then return end

    -- Atualiza metadados do celular
    phoneMeta.has_sim = true
    phoneMeta.sim_id = simMeta.id or simMeta.sim_id
    phoneMeta.phone_number = simNumber
    phoneMeta.formatted_number = simMeta.formatted_number or SimManager.FormatNumber(simNumber)
    phoneMeta.hazePhoneNumber = tostring(simNumber)
    phoneMeta.lbPhoneNumber = tostring(simNumber)
    phoneMeta.sim_operator = simMeta.operator or "Badger Wireless"
    phoneMeta.is_burner = simMeta.is_burner or false
    phoneMeta.expires_at = simMeta.expires_at or nil
    phoneMeta.phone_status = "Desligado" -- Por segurança entra desligado

    exports.ox_inventory:SetMetadata(source, phoneSlot, phoneMeta)

    TriggerClientEvent("ox_lib:notify", source, {
        title = "Celular",
        description = string.format("Chip inserido com sucesso: %s (%s). Ligue o celular para usar.", phoneMeta.formatted_number, phoneMeta.sim_operator),
        type = "success"
    })
end)

--- Ejetar Chip SIM do Aparelho
RegisterNetEvent("haze_simcard:server:ejectSim", function(phoneSlot)
    local source = source
    if not Security.CheckRateLimit(source, "eject_sim", 1500) then return end

    local phoneItem = exports.ox_inventory:GetSlot(source, phoneSlot)
    if not phoneItem or phoneItem.name ~= Config.PhoneItem then return end

    local phoneMeta = phoneItem.metadata or {}
    if not phoneMeta.has_sim or not phoneMeta.phone_number or phoneMeta.phone_number == 0 then
        TriggerClientEvent("ox_lib:notify", source, {
            title = "Celular",
            description = "O aparelho não possui nenhum chip para ejetar.",
            type = "error"
        })
        return
    end

    -- Desliga o aparelho se estiver ligado
    if phoneMeta.phone_status == "Ligado" then
        PhoneBridge.SetPhoneNumber(source, nil)
        PhoneBridge.ClosePhone(source)
    end

    -- Determina o item correspondente da operadora
    local simItemName = "sim_badger"
    if phoneMeta.is_burner then
        simItemName = Config.Burner.item
    else
        for _, op in pairs(Config.Operators) do
            if op.label == phoneMeta.sim_operator then
                simItemName = op.item
                break
            end
        end
    end

    local simMetadata = {
        id = phoneMeta.sim_id,
        sim_id = phoneMeta.sim_id,
        simnumber = phoneMeta.phone_number,
        phone_number = phoneMeta.phone_number,
        formatsimnumber = phoneMeta.formatted_number,
        formatted_number = phoneMeta.formatted_number,
        operator = phoneMeta.sim_operator,
        is_burner = phoneMeta.is_burner,
        expires_at = phoneMeta.expires_at,
        description = string.format("Operadora: %s | Número: %s", phoneMeta.sim_operator, phoneMeta.formatted_number)
    }

    local added = exports.ox_inventory:AddItem(source, simItemName, 1, simMetadata)
    if not added then
        TriggerClientEvent("ox_lib:notify", source, {
            title = "Inventário Cheio",
            description = "Libere espaço na mochila para ejetar o chip SIM.",
            type = "error"
        })
        return
    end

    -- Limpa os metadados do celular
    phoneMeta.has_sim = false
    phoneMeta.phone_number = 0
    phoneMeta.formatted_number = "Sem Chip"
    phoneMeta.hazePhoneNumber = nil
    phoneMeta.lbPhoneNumber = nil
    phoneMeta.sim_operator = nil
    phoneMeta.sim_id = nil
    phoneMeta.is_burner = nil
    phoneMeta.expires_at = nil
    phoneMeta.phone_status = "Desligado"

    exports.ox_inventory:SetMetadata(source, phoneSlot, phoneMeta)

    TriggerClientEvent("ox_lib:notify", source, {
        title = "Celular",
        description = "Chip SIM ejetado com sucesso.",
        type = "inform"
    })
end)

--- Callback de Abertura do Celular
lib.callback.register("haze_simcard:server:canOpenPhone", function(source, slot)
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or item.name ~= Config.PhoneItem then
        return false, "no_phone"
    end

    local meta = item.metadata or {}

    if not meta.has_sim or not meta.phone_number or meta.phone_number == 0 then
        return false, "no_sim"
    end

    if meta.phone_status ~= "Ligado" then
        return false, "turned_off"
    end

    -- Se o jogador estiver com Jammer ativo, o ruído eletromagnético bloqueia a rede do aparelho
    if TrackingManager and TrackingManager.IsPlayerJammed(source) then
        return false, "jammer_active"
    end

    if meta.is_burner and BurnerManager.IsExpired(meta) then
        local expiredNumber = meta.phone_number
        meta.has_sim = false
        meta.phone_number = 0
        meta.formatted_number = "Sem Chip"
        meta.phone_status = "Desligado"
        meta.hazePhoneNumber = nil
        meta.lbPhoneNumber = nil
        meta.sim_operator = nil
        meta.sim_id = nil
        meta.is_burner = nil
        meta.expires_at = nil
        exports.ox_inventory:SetMetadata(source, slot, meta)
        exports.ox_inventory:AddItem(source, Config.Burner.burnedItem, 1)
        Database.DeleteSim(expiredNumber)
        PhoneBridge.SetPhoneNumber(source, nil)
        return false, "burner_expired"
    end

    -- Garante que a rota de rede esteja ativa para este jogador
    PhoneBridge.SetPhoneNumber(source, meta.phone_number)
    return true, meta.phone_number
end)

--- Backfill automático ao carregar o jogador no servidor
RegisterNetEvent("haze_simcard:server:onPlayerLoaded", function()
    local source = source
    Wait(2000)

    local citizenId = Security.GetCitizenId(source)
    if not citizenId then return end

    local phones = exports.ox_inventory:Search(source, "slots", Config.PhoneItem)
    if not phones or #phones == 0 then return end

    -- Busca o número cadastrado do jogador
    local playerNumber = MySQL.scalar.await("SELECT `phone_number` FROM `phone_phones` WHERE `owner_id` = ? OR `id` = ? LIMIT 1", { citizenId, citizenId })

    if not playerNumber then
        playerNumber = MySQL.scalar.await("SELECT `number` FROM `haze_simcards` WHERE `owner` = ? LIMIT 1", { citizenId })
    end

    if not playerNumber then return end

    for _, phone in pairs(phones) do
        local meta = phone.metadata or {}
        -- Se o telefone ainda não possui os metadados do haze_simcard
        if not meta.phone_status or meta.has_sim == nil then
            meta.has_sim = true
            meta.sim_id = "MIG-" .. playerNumber
            meta.phone_number = playerNumber
            meta.formatted_number = SimManager.FormatNumber(playerNumber)
            meta.hazePhoneNumber = tostring(playerNumber)
            meta.lbPhoneNumber = tostring(playerNumber)
            meta.sim_operator = "Badger Wireless"
            meta.phone_status = "Ligado"
            exports.ox_inventory:SetMetadata(source, phone.slot, meta)
            PhoneBridge.SetPhoneNumber(source, playerNumber)
            break
        end
    end
end)

--- Callbacks de Loja
lib.callback.register("haze_simcard:server:buySim", function(source, operatorKey, isBurner, customNumber)
    local success, message = SimManager.PurchaseSim(source, operatorKey, isBurner, customNumber)
    return success, message
end)

lib.callback.register("haze_simcard:server:buyPhone", function(source)
    if not Security.CheckRateLimit(source, "buy_phone", 2000) then
        return false, "Aguarde antes de realizar outra transação."
    end

    if not Security.ValidateShopDistance(source, 5.0) then
        Security.Log("SECURITY_ALERT", string.format("Jogador %s tentou comprar aparelho celular fora da loja.", source))
        return false, "Você precisa estar no balcão de atendimento de uma loja para comprar um aparelho."
    end

    local price = Config.PhonePrice or 500
    if not Security.HasMoney(source, price) then
        return false, string.format("Saldo insuficiente. Preço: $%s", price)
    end

    Security.RemoveMoney(source, price)
    local metadata = {
        has_sim = false,
        phone_number = 0,
        formatted_number = "Sem Chip",
        phone_status = "Desligado"
    }
    exports.ox_inventory:AddItem(source, Config.PhoneItem, 1, metadata)
    Security.Log("PURCHASE_PHONE", string.format("Cidadão %s (%s) comprou um novo aparelho smartphone por $%s.", Security.GetCharacterName(source), Security.GetCitizenId(source) or "N/A", price))
    return true, "Aparelho celular adquirido com sucesso."
end)

lib.callback.register("haze_simcard:server:getPlayerSims", function(source)
    local citizenId = Security.GetCitizenId(source)
    if not citizenId then return {} end
    return Database.GetPlayerSims(citizenId)
end)

lib.callback.register("haze_simcard:server:duplicateSim", function(source, number)
    return SimManager.DuplicateSim(source, number)
end)

lib.callback.register("haze_simcard:server:blockSim", function(source, number)
    return SimManager.BlockSim(source, number)
end)

lib.callback.register("haze_simcard:server:portability", function(source, number, newOp)
    return SimManager.Portability(source, number, newOp)
end)

lib.callback.register("haze_simcard:server:policeLookup", function(source, number)
    return SimManager.PoliceLookup(source, number)
end)

lib.callback.register("haze_simcard:server:buyTactical", function(source, itemType)
    return SimManager.PurchaseTacticalItem(source, itemType)
end)

