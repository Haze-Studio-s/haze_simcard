-- Gerenciamento de controles físicos do celular e manipulação de chips

--- Export chamado pelo ox_inventory ao usar o item phone
exports("openPhone", function(data, slot)
    local slotNum = (type(slot) == "table" and slot.slot) or (type(data) == "table" and data.slot) or slot
    if not slotNum then return end

    lib.callback("haze_simcard:server:canOpenPhone", false, function(canOpen, result)
        if canOpen then
            -- Aciona abertura do telefone através da bridge universal
            PhoneBridge.ToggleDisabled(false)
            Wait(50)
            PhoneBridge.ToggleOpen(true)
        else
            if result == "turned_off" then
                lib.notify({
                    title = "Celular",
                    description = "O aparelho está desligado. Use a opção 'Ligar / Desligar' no menu do item para ativá-lo.",
                    type = "error"
                })
            elseif result == "no_sim" then
                lib.notify({
                    title = "Celular",
                    description = "Nenhum chip SIM inserido. Insira um chip válido para utilizar o aparelho.",
                    type = "error"
                })
            elseif result == "burner_expired" then
                lib.notify({
                    title = "AnonSIM Descartável",
                    description = "⚠️ O chip descartável deste aparelho expirou e os circuitos foram destruídos.",
                    type = "error"
                })
            elseif result == "jammer_active" then
                lib.notify({
                    title = "Sem Sinal de Rede",
                    description = "⚠️ Seu aparelho está sem sinal devido à interferência do seu Bloqueador de Sinal (Jammer) ativo!",
                    type = "error",
                    duration = 5000
                })
            else
                lib.notify({
                    title = "Celular",
                    description = "Não foi possível ligar o aparelho no momento.",
                    type = "error"
                })
            end
        end
    end, slotNum)
end)

--- Export chamado ao usar um item de chip SIM
exports("useSimCard", function(data, slot)
    local simSlot = (type(slot) == "table" and slot.slot) or (type(data) == "table" and data.slot) or slot
    if not simSlot then return end

    -- Busca telefones na mochila
    local phones = exports.ox_inventory:Search("slots", Config.PhoneItem)
    if not phones or #phones == 0 then
        lib.notify({
            title = "Chip SIM",
            description = "Você precisa de um celular na mochila para inserir este chip.",
            type = "error"
        })
        return
    end

    local availablePhones = {}
    for _, p in pairs(phones) do
        local meta = p.metadata or {}
        if not meta.has_sim or not meta.phone_number or meta.phone_number == 0 then
            table.insert(availablePhones, p)
        end
    end

    if #availablePhones == 0 then
        lib.notify({
            title = "Chip SIM",
            description = "Todos os seus aparelhos celulares já possuem um chip inserido.",
            type = "error"
        })
        return
    end

    local function ExecuteInsert(targetPhoneSlot)
        PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
        if lib.progressBar({
            duration = 2200,
            label = "Inserindo chip SIM no aparelho...",
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, combat = true },
            anim = {
                dict = "cellphone@",
                clip = "cellphone_text_in"
            },
            prop = {
                model = `prop_npc_phone_02`,
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        }) then
            PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
            TriggerServerEvent("haze_simcard:server:insertSim", targetPhoneSlot, simSlot)
        end
    end

    -- Se tiver apenas 1 telefone livre, insere direto
    if #availablePhones == 1 then
        ExecuteInsert(availablePhones[1].slot)
    else
        -- Se tiver mais de um celular sem chip, pergunta em qual deseja inserir
        local options = {}
        for _, p in ipairs(availablePhones) do
            table.insert(options, {
                title = string.format("Celular (Slot %s)", p.slot),
                description = "Inserir chip neste aparelho",
                icon = "fa-solid fa-mobile-screen",
                onSelect = function()
                    ExecuteInsert(p.slot)
                end
            })
        end

        lib.registerContext({
            id = "haze_simcard_pick_phone",
            title = "Escolha o Aparelho",
            options = options
        })
        lib.showContext("haze_simcard_pick_phone")
    end
end)

--- Evento acionado pelo botão "Ligar / Desligar" no ox_inventory
RegisterNetEvent("haze_simcard:client:togglePower", function(slot)
    local slotNum = (type(slot) == "table" and slot.slot) or slot
    if not slotNum then return end

    exports.ox_inventory:closeInventory()

    PlaySoundFrontend(-1, "Menu_Accept", "Phone_SoundSet_Default", true)

    if lib.progressBar({
        duration = 1800,
        label = "Alternando energia do celular...",
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = {
            dict = "cellphone@",
            clip = "cellphone_text_in"
        },
        prop = {
            model = `prop_npc_phone_02`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        }
    }) then
        PlaySoundFrontend(-1, "Menu_Back", "Phone_SoundSet_Default", true)
        TriggerServerEvent("haze_simcard:server:togglePower", slotNum)
    end
end)

--- Evento acionado pelo botão "Gerenciar Chip SIM" no ox_inventory
RegisterNetEvent("haze_simcard:client:manageSimSlot", function(slot)
    local slotNum = (type(slot) == "table" and slot.slot) or slot
    if not slotNum then return end

    exports.ox_inventory:closeInventory()

    local playerItems = exports.ox_inventory:GetPlayerItems()
    local phoneItem = nil

    for _, it in pairs(playerItems) do
        if it.slot == slotNum and it.name == Config.PhoneItem then
            phoneItem = it
            break
        end
    end

    if not phoneItem then return end

    local meta = phoneItem.metadata or {}
    local menuOptions = {}

    if meta.has_sim and meta.phone_number and meta.phone_number ~= 0 then
        local descStr = string.format("Número atual: %s (%s)", meta.formatted_number or meta.phone_number, meta.sim_operator or "Operadora")
        if meta.is_burner and meta.expires_at then
            local now = GetCloudTimeAsInt()
            local remainingSecs = math.max(0, meta.expires_at - now)
            local remainingHours = math.floor(remainingSecs / 3600)
            local remainingMins = math.floor((remainingSecs % 3600) / 60)
            descStr = string.format("%s | ⏳ Expira em: %sh %sm", descStr, remainingHours, remainingMins)
        end

        -- Aparelho com chip: opção de ejetar
        table.insert(menuOptions, {
            title = "Ejetar Chip SIM",
            description = descStr,
            icon = "fa-solid fa-eject",
            onSelect = function()
                PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                if lib.progressBar({
                    duration = 2200,
                    label = "Ejetando bandeja do chip SIM...",
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, combat = true },
                    anim = {
                        dict = "cellphone@",
                        clip = "cellphone_text_in"
                    },
                    prop = {
                        model = `prop_npc_phone_02`,
                        bone = 28422,
                        pos = vec3(0.0, 0.0, 0.0),
                        rot = vec3(0.0, 0.0, 0.0)
                    }
                }) then
                    PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                    TriggerServerEvent("haze_simcard:server:ejectSim", slotNum)
                end
            end
        })
    else
        -- Aparelho sem chip: listar chips disponíveis na mochila
        local availableSims = {}
        for _, it in pairs(playerItems) do
            if it.name:find("^sim_") and it.name ~= "burned_sim" then
                table.insert(availableSims, it)
            end
        end

        if #availableSims == 0 then
            table.insert(menuOptions, {
                title = "Nenhum Chip Disponível",
                description = "Você não possui nenhum chip solto na mochila para inserir.",
                disabled = true,
                icon = "fa-solid fa-triangle-exclamation"
            })
        else
            for _, simIt in ipairs(availableSims) do
                local sMeta = simIt.metadata or {}
                local numStr = sMeta.formatted_number or sMeta.simnumber or "Novo Chip"
                local opStr = sMeta.operator or simIt.label
                table.insert(menuOptions, {
                    title = string.format("Inserir %s", opStr),
                    description = string.format("Número: %s", numStr),
                    icon = "fa-solid fa-microchip",
                    onSelect = function()
                        PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                        if lib.progressBar({
                            duration = 2000,
                            label = "Inserindo chip SIM...",
                            useWhileDead = false,
                            canCancel = true,
                            disable = { move = true, combat = true },
                            anim = {
                                dict = "cellphone@",
                                clip = "cellphone_text_in"
                            },
                            prop = {
                                model = `prop_npc_phone_02`,
                                bone = 28422,
                                pos = vec3(0.0, 0.0, 0.0),
                                rot = vec3(0.0, 0.0, 0.0)
                            }
                        }) then
                            PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                            TriggerServerEvent("haze_simcard:server:insertSim", slotNum, simIt.slot)
                        end
                    end
                })
            end
        end
    end

    lib.registerContext({
        id = "haze_simcard_manage_slot",
        title = "Gerenciar Chip SIM",
        options = menuOptions
    })

    lib.showContext("haze_simcard_manage_slot")
end)

-- Eventos de controle de sessão enviados pelo servidor
RegisterNetEvent("haze_simcard:client:setPhoneSession", function(phoneNumber)
    PhoneBridge.SetPhoneNumber(phoneNumber)
end)

RegisterNetEvent("haze_simcard:client:forceClosePhone", function()
    PhoneBridge.ClosePhone()
end)

RegisterNetEvent("haze_simcard:client:forceTurnOffPhone", function()
    PhoneBridge.ClosePhone()
    PhoneBridge.ToggleDisabled(true)
end)
