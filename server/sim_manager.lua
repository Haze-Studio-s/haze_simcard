SimManager = {}

--- Formata um número para o padrão de Los Santos: (555) XXX-XXXX
---@param number string|number
---@return string
function SimManager.FormatNumber(number)
    local numStr = tostring(number)
    if #numStr == 7 then
        return string.format("(555) %s-%s", numStr:sub(1, 3), numStr:sub(4, 7))
    elseif #numStr >= 8 then
        return string.format("(%s) %s-%s", numStr:sub(1, 3), numStr:sub(4, 6), numStr:sub(7))
    end
    return numStr
end

--- Gera um número de telefone único baseado no prefixo da operadora
---@param prefix string
---@return string
function SimManager.GenerateNumber(prefix)
    local number = nil
    repeat
        local randomSuffix = math.random(100000, 999999)
        number = tostring(prefix) .. tostring(randomSuffix)
    until not Database.IsNumberTaken(number)
    return number
end

--- Cria um identificador único de chip SIM físico
---@param isBurner boolean?
---@return string
function SimManager.GenerateSimId(isBurner)
    local tag = isBurner and "BURN" or "SIM"
    return string.format("%s-%s-%s", tag, math.random(1000, 9999), math.random(1000, 9999))
end

--- Compra um chip SIM de operadora ou descartável
---@param source number
---@param operatorKey string
---@param isBurner boolean
---@param customNumber string?
---@return boolean, string
function SimManager.PurchaseSim(source, operatorKey, isBurner, customNumber)
    if not Security.CheckRateLimit(source, "purchase_sim", 2000) then
        return false, "Aguarde antes de realizar outra transação."
    end

    if not Security.ValidateShopDistance(source, 5.0) then
        Security.Log("SECURITY_ALERT", string.format("Jogador %s tentou comprar chip sem estar próximo a uma loja.", source))
        return false, "Você precisa estar no balcão de atendimento de uma loja para realizar esta operação."
    end

    local citizenId = Security.GetCitizenId(source)
    if not citizenId then
        return false, "Cidadão não identificado."
    end

    local price = 0
    local operatorData = Config.Operators[operatorKey]
    local itemName = nil
    local operatorLabel = "AnonSIM"
    local prefix = "6"
    local expiresAt = nil

    if isBurner then
        price = Config.Burner.price
        itemName = Config.Burner.item
        prefix = Config.Burner.prefix
        operatorLabel = Config.Burner.label
        expiresAt = os.time() + Config.BurnerDuration
    else
        if not operatorData then
            return false, "Operadora inválida."
        end
        price = operatorData.price
        itemName = operatorData.item
        prefix = operatorData.prefix
        operatorLabel = operatorData.label

        -- Desconto total para policiais em serviço na EyeFind
        if operatorData.policeDiscount and Security.IsPolice(source) then
            price = 0
        end
    end

    -- Tratamento de Número Personalizado
    local finalNumber = nil
    if customNumber and #customNumber >= 6 and #customNumber <= 10 and tonumber(customNumber) then
        if Database.IsNumberTaken(customNumber) then
            return false, "Este número personalizado já está em uso por outro cidadão."
        end

        local voucherCount = exports.ox_inventory:GetItemCount(source, Config.CustomNumberItem)
        if voucherCount and voucherCount > 0 then
            exports.ox_inventory:RemoveItem(source, Config.CustomNumberItem, 1)
        else
            price = price + Config.CustomNumberPrice
        end
        finalNumber = tostring(customNumber)
    else
        finalNumber = SimManager.GenerateNumber(prefix)
    end

    -- Validação e débito financeiro
    if price > 0 then
        local hasFunds = Security.HasMoney(source, price)
        if not hasFunds then
            return false, string.format("Saldo insuficiente. Necessário: $%s", price)
        end
        Security.RemoveMoney(source, price)
    end

    local simId = SimManager.GenerateSimId(isBurner)

    -- Registro no banco de dados
    local dbSuccess = Database.CreateSim({
        id = simId,
        number = finalNumber,
        operator = operatorLabel,
        owner = isBurner and nil or citizenId,
        is_burner = isBurner,
        expires_at = expiresAt
    })

    if not dbSuccess then
        return false, "Erro ao registrar o chip no banco de dados."
    end

    local descriptionText = isBurner
        and string.format("AnonSIM Descartável | Número: %s | Expira em: %s", SimManager.FormatNumber(finalNumber), os.date("%d/%m/%Y às %H:%M", expiresAt))
        or string.format("Operadora: %s | Número: %s (Registrado)", operatorLabel, SimManager.FormatNumber(finalNumber))

    -- Entrega do item no inventário
    local metadata = {
        id = simId,
        sim_id = simId,
        simnumber = tonumber(finalNumber) or finalNumber,
        phone_number = tonumber(finalNumber) or finalNumber,
        formatsimnumber = SimManager.FormatNumber(finalNumber),
        formatted_number = SimManager.FormatNumber(finalNumber),
        operator = operatorLabel,
        is_burner = isBurner,
        expires_at = expiresAt,
        description = descriptionText
    }

    local addSuccess = exports.ox_inventory:AddItem(source, itemName, 1, metadata)
    if not addSuccess then
        return false, "Seu inventário está cheio para receber o chip."
    end

    Security.Log("PURCHASE_SIM", string.format("Cidadão %s (%s) adquiriu chip %s (Nº %s) por $%s.", Security.GetCharacterName(source), citizenId, operatorLabel, finalNumber, price))
    return true, string.format("Chip %s adquirido com sucesso: %s", operatorLabel, SimManager.FormatNumber(finalNumber))
end

--- Emite uma 2ª via (duplicata) de um chip registrado
---@param source number
---@param targetNumber string
---@return boolean, string
function SimManager.DuplicateSim(source, targetNumber)
    if not Security.CheckRateLimit(source, "duplicate_sim", 2000) then
        return false, "Aguarde antes de realizar outra transação."
    end

    if not Security.ValidateShopDistance(source, 5.0) then
        Security.Log("SECURITY_ALERT", string.format("Jogador %s tentou emitir 2ª via longe da loja.", source))
        return false, "Você precisa estar no balcão de uma operadora para solicitar 2ª via."
    end

    local citizenId = Security.GetCitizenId(source)
    local sim = Database.GetSimByNumber(targetNumber)

    if not sim or sim.owner ~= citizenId or sim.is_burner == 1 then
        return false, "Linha telefônica não encontrada ou não pertence a você."
    end

    local operatorKey = 'badger'
    for k, v in pairs(Config.Operators) do
        if v.label == sim.operator then
            operatorKey = k
            break
        end
    end
    local opData = Config.Operators[operatorKey]
    local price = opData and opData.duplicatePrice or 100
    local itemName = opData and opData.item or 'sim_badger'

    if not Security.HasMoney(source, price) then
        return false, string.format("Saldo insuficiente para 2ª via. Necessário: $%s", price)
    end

    Security.RemoveMoney(source, price)

    -- Gera um novo ID único invalidando qualquer cópia antiga perdida/roubada
    local newSimId = SimManager.GenerateSimId(false)
    Database.UnblockAndAssignId(targetNumber, newSimId)

    local metadata = {
        id = newSimId,
        sim_id = newSimId,
        simnumber = tonumber(targetNumber) or targetNumber,
        phone_number = tonumber(targetNumber) or targetNumber,
        formatsimnumber = SimManager.FormatNumber(targetNumber),
        formatted_number = SimManager.FormatNumber(targetNumber),
        operator = sim.operator,
        is_burner = false,
        description = string.format("2ª Via | Operadora: %s | Número: %s", sim.operator, SimManager.FormatNumber(targetNumber))
    }

    exports.ox_inventory:AddItem(source, itemName, 1, metadata)
    Security.Log("DUPLICATE_SIM", string.format("Cidadão %s (%s) emitiu 2ª via da linha %s.", Security.GetCharacterName(source), citizenId, targetNumber))
    return true, string.format("2ª via da linha %s emitida com sucesso.", SimManager.FormatNumber(targetNumber))
end

--- Bloqueia uma linha telefônica
---@param source number
---@param targetNumber string
---@return boolean, string
function SimManager.BlockSim(source, targetNumber)
    if not Security.CheckRateLimit(source, "block_sim", 2000) then
        return false, "Aguarde um momento."
    end

    if not Security.ValidateShopDistance(source, 5.0) then
        return false, "Você precisa estar no balcão de uma operadora para bloquear sua linha."
    end

    local citizenId = Security.GetCitizenId(source)
    local sim = Database.GetSimByNumber(targetNumber)

    if not sim or sim.owner ~= citizenId or sim.is_burner == 1 then
        return false, "Linha telefônica não encontrada ou não pertence a você."
    end

    local blockedId = "BLOCKED-" .. math.random(100000, 999999)
    Database.BlockAndRotateId(targetNumber, blockedId)

    -- Se o telefone estiver ativo em algum jogador, desconecta
    local currentHolder = PhoneBridge.GetSourceFromNumber(targetNumber)
    if currentHolder then
        PhoneBridge.ClosePhone(currentHolder)
        TriggerClientEvent("haze_simcard:client:forceTurnOffPhone", currentHolder)
    end

    Security.Log("BLOCK_SIM", string.format("Cidadão %s (%s) bloqueou a linha %s.", Security.GetCharacterName(source), citizenId, targetNumber))
    return true, string.format("Linha %s bloqueada. Chips antigos foram invalidados.", SimManager.FormatNumber(targetNumber))
end

--- Realiza a portabilidade numérica para outra operadora
---@param source number
---@param targetNumber string
---@param newOperatorKey string
---@return boolean, string
function SimManager.Portability(source, targetNumber, newOperatorKey)
    if not Security.CheckRateLimit(source, "portability", 2000) then
        return false, "Aguarde um momento."
    end

    if not Security.ValidateShopDistance(source, 5.0) then
        return false, "Você precisa estar no balcão de uma operadora para solicitar portabilidade."
    end

    local citizenId = Security.GetCitizenId(source)
    local sim = Database.GetSimByNumber(targetNumber)
    local newOpData = Config.Operators[newOperatorKey]

    if not sim or sim.owner ~= citizenId or sim.is_burner == 1 then
        return false, "Linha telefônica não encontrada ou não elegível para portabilidade."
    end

    if not newOpData then
        return false, "Operadora de destino inválida."
    end

    if sim.operator == newOpData.label then
        return false, "Sua linha já pertence a esta operadora."
    end

    local price = Config.PortabilityPrice or 500
    if not Security.HasMoney(source, price) then
        return false, string.format("Saldo insuficiente para portabilidade. Taxa: $%s", price)
    end

    Security.RemoveMoney(source, price)
    Database.UpdateOperator(targetNumber, newOpData.label)

    -- Gera um novo chip da nova operadora
    local newSimId = SimManager.GenerateSimId(false)
    Database.UnblockAndAssignId(targetNumber, newSimId)

    local metadata = {
        id = newSimId,
        sim_id = newSimId,
        simnumber = tonumber(targetNumber) or targetNumber,
        phone_number = tonumber(targetNumber) or targetNumber,
        formatsimnumber = SimManager.FormatNumber(targetNumber),
        formatted_number = SimManager.FormatNumber(targetNumber),
        operator = newOpData.label,
        is_burner = false,
        description = string.format("Operadora: %s | Número: %s (Portado)", newOpData.label, SimManager.FormatNumber(targetNumber))
    }

    -- Se o jogador tiver um celular equipado com esse número, atualiza os metadados do aparelho
    local phones = exports.ox_inventory:Search(source, "slots", Config.PhoneItem)
    if phones then
        for _, p in pairs(phones) do
            if p.metadata and tostring(p.metadata.phone_number) == tostring(targetNumber) then
                p.metadata.sim_operator = newOpData.label
                p.metadata.sim_id = newSimId
                exports.ox_inventory:SetMetadata(source, p.slot, p.metadata)
            end
        end
    end

    exports.ox_inventory:AddItem(source, newOpData.item, 1, metadata)
    Security.Log("PORTABILITY", string.format("Cidadão %s (%s) portou a linha %s para %s.", Security.GetCharacterName(source), citizenId, targetNumber, newOpData.label))
    return true, string.format("Portabilidade concluída! Sua linha %s agora opera na %s.", SimManager.FormatNumber(targetNumber), newOpData.label)
end

--- Compra e manutenção de equipamentos táticos no mercado clandestino
---@param source number
---@param itemType string
---@return boolean, string
function SimManager.PurchaseTacticalItem(source, itemType)
    if not Security.CheckRateLimit(source, "buy_tactical", 2000) then
        return false, "Aguarde um momento."
    end

    if not Security.ValidateShopDistance(source, 5.0) then
        Security.Log("SECURITY_ALERT", string.format("Jogador %s tentou interagir com mercador clandestino fora do raio.", source))
        return false, "Você precisa estar no local do mercador clandestino para negociar este equipamento."
    end

    if itemType == "recharge" then
        local rechargeCost = 300
        if not Security.HasMoney(source, rechargeCost) then
            return false, string.format("Saldo insuficiente para recarga. Custo: $%s", rechargeCost)
        end

        local items = exports.ox_inventory:Search(source, "slots", Config.Tracking.jammerItem)
        if not items or #items == 0 then
            return false, "Você não possui nenhum Bloqueador de Sinal na mochila para recarregar."
        end

        local rechargedSlot = nil
        for _, it in pairs(items) do
            local meta = it.metadata or {}
            local batt = tonumber(meta.battery) or 100
            if batt < 100 then
                rechargedSlot = it.slot
                meta.battery = 100
                meta.description = string.format("Status: %s | Bateria: 100%%.", meta.is_active and "LIGADO" or "DESLIGADO")
                exports.ox_inventory:SetMetadata(source, it.slot, meta)
                break
            end
        end

        if not rechargedSlot then
            return false, "Todos os seus Bloqueadores já estão com a bateria em 100%."
        end

        Security.RemoveMoney(source, rechargeCost)
        Security.Log("TACTICAL_RECHARGE", string.format("Jogador %s recarregou bateria do Jammer por $%s.", Security.GetCharacterName(source), rechargeCost))
        return true, string.format("Baterias de lítio do Bloqueador substituídas com sucesso por $%s (100%% de carga).", rechargeCost)
    end

    local price = 0
    local itemName = nil
    local itemLabel = ""
    local metadata = {}

    if itemType == "tracker" then
        price = Config.Tracking.trackerPrice or 7500
        itemName = Config.Tracking.trackerItem
        itemLabel = "Triangulador IMSI de Sinal"
        metadata = {
            description = string.format("Triangulador tático de antenas ERB. Série: IMSI-%s", math.random(1000, 9999))
        }
    elseif itemType == "jammer" then
        price = Config.Tracking.jammerPrice or 5000
        itemName = Config.Tracking.jammerItem
        itemLabel = "Bloqueador de Frequência Jammer"
        metadata = {
            battery = 100,
            is_active = false,
            jammer_status = "Desligado",
            description = "Status: DESLIGADO | Bateria: 100%."
        }
    else
        return false, "Item inválido."
    end

    if not Security.HasMoney(source, price) then
        return false, string.format("Saldo insuficiente. Necessário: $%s", price)
    end

    Security.RemoveMoney(source, price)
    local added = exports.ox_inventory:AddItem(source, itemName, 1, metadata)
    if not added then
        return false, "Mochila cheia para receber o equipamento."
    end

    Security.Log("TACTICAL_BUY", string.format("Jogador %s comprou %s por $%s.", Security.GetCharacterName(source), itemLabel, price))
    return true, string.format("%s adquirido com sucesso por $%s.", itemLabel, price)
end

--- Consulta forense de linha telefônica pela polícia
---@param source number
---@param targetNumber string
---@return boolean, table|string
function SimManager.PoliceLookup(source, targetNumber)
    if not Security.CheckRateLimit(source, "police_lookup", 2000) then
        return false, "Aguarde antes de realizar outra consulta investigativa."
    end

    local hasAccess, reason = Security.ValidatePoliceAccess(source)
    if not hasAccess then
        Security.Log("SECURITY_ALERT", string.format("Jogador %s tentou consulta policial sem acesso (%s).", source, reason))
        return false, reason
    end

    local cleanNumber = tostring(targetNumber):gsub("%D", "")
    if #cleanNumber < 6 then
        return false, "Número de telefone informado é inválido."
    end

    local sim = Database.GetSimByNumber(cleanNumber)
    if not sim then
        return false, string.format("Número %s não consta na base de dados das operadoras estaduais.", SimManager.FormatNumber(cleanNumber))
    end

    -- Registra log de auditoria policial
    Security.Log("POLICE_LOOKUP", string.format("Oficial %s (Doc: %s) realizou consulta da linha: %s", Security.GetCharacterName(source), Security.GetCitizenId(source), cleanNumber))

    -- Checa se o transmissor está com sinal ativo no momento
    local targetSrc = PhoneBridge.GetSourceFromNumber(cleanNumber)
    local signalText = "📵 Fora de área ou aparelho desligado"
    if targetSrc and GetPlayerPing(targetSrc) > 0 then
        signalText = "📡 Sinal ativo detectado nas torres de transmissão da região"
    end

    if sim.is_burner == 1 then
        return true, {
            number = SimManager.FormatNumber(cleanNumber),
            operator = sim.operator,
            owner = "LINHA PRÉ-PAGA CLANDESTINA (SEM REGISTRO DE TITULAR)",
            status = "Anônimo / Clandestino",
            signal = signalText,
            is_burner = true
        }
    end

    local charinfoJson = MySQL.scalar.await("SELECT `charinfo` FROM `players` WHERE `citizenid` = ? LIMIT 1", { sim.owner })
    local ownerName = "Cidadão Não Encontrado"
    if charinfoJson then
        local charinfo = json.decode(charinfoJson)
        if charinfo then
            ownerName = string.format("%s %s (Doc: %s)", charinfo.firstname or "", charinfo.lastname or "", sim.owner)
        end
    end

    return true, {
        number = SimManager.FormatNumber(cleanNumber),
        operator = sim.operator,
        owner = ownerName,
        status = sim.is_blocked == 1 and "Bloqueado" or "Ativo",
        signal = signalText,
        is_burner = false
    }
end
