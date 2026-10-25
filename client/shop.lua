local spawnedPeds = {}
local createdZones = {}

-- Criação dos NPCs e registro de alvos ox_target
CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        local modelHash = joaat(shop.pedModel)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(50)
        end

        local ped = CreatePed(4, modelHash, shop.coords.x, shop.coords.y, shop.coords.z - 1.0, shop.coords.w, false, true)
        SetEntityHeading(ped, shop.coords.w)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        table.insert(spawnedPeds, ped)

        local targetOptions = {
            {
                name = "haze_simcard_shop_" .. shop.id,
                icon = "fa-solid fa-headset",
                label = shop.allowBurner and "Negociar Comunicações" or "Atendimento da Operadora",
                distance = 2.5,
                onSelect = function()
                    OpenShopMenu(shop)
                end
            }
        }

        -- Se for loja oficial (não-clandestina), adiciona opção de terminal policial
        if not shop.allowBurner then
            local policeGroups = {}
            for job, _ in pairs(Config.PoliceJobs) do
                table.insert(policeGroups, job)
            end

            table.insert(targetOptions, {
                name = "haze_simcard_police_" .. shop.id,
                icon = "fa-solid fa-shield-halved",
                label = "Terminal de Investigação Policial",
                groups = policeGroups,
                distance = 2.5,
                onSelect = function()
                    OpenPoliceLookupMenu()
                end
            })
        end

        exports.ox_target:addLocalEntity(ped, targetOptions)
    end

    -- Criação dos Terminais Policiais nas Delegacias de Polícia
    local policeGroups = {}
    for job, _ in pairs(Config.PoliceJobs) do
        table.insert(policeGroups, job)
    end

    for _, term in ipairs(Config.PoliceTerminals or {}) do
        local zoneId = exports.ox_target:addBoxZone({
            coords = term.coords,
            size = term.size or vec3(1.2, 1.2, 1.5),
            rotation = term.heading or 0.0,
            debug = false,
            options = {
                {
                    name = "haze_police_term_" .. term.id,
                    icon = "fa-solid fa-desktop",
                    label = "Acessar Terminal de Telecomunicações",
                    groups = policeGroups,
                    distance = 2.0,
                    onSelect = function()
                        OpenPoliceLookupMenu()
                    end
                }
            }
        })
        table.insert(createdZones, zoneId)
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    for _, zId in ipairs(createdZones) do
        exports.ox_target:removeZone(zId)
    end
end)

--- Abre o menu principal de atendimento da loja
function OpenShopMenu(shop)
    PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
    local options = {}

    -- Se for o mercado clandestino
    if shop.allowBurner then
        -- AnonSIM Descartável
        table.insert(options, {
            title = string.format("AnonSIM Descartável ($%s)", Config.Burner.price),
            description = "Linha anônima pré-paga sem registro de documento. Expira em 24h.",
            icon = "fa-solid fa-mask",
            onSelect = function()
                OpenNumberTypeMenu("burner", true, Config.Burner)
            end
        })

        -- Celular sem registro
        table.insert(options, {
            title = string.format("Aparelho Celular Limpo ($%s)", Config.PhonePrice),
            description = "Smartphone sem IMEI registrado nos servidores de Los Santos.",
            icon = "fa-solid fa-mobile-screen",
            onSelect = function()
                local alert = lib.alertDialog({
                    header = "Mercado Clandestino",
                    content = string.format("Comprar um aparelho celular não registrado por **$%s**?", Config.PhonePrice),
                    centered = true,
                    cancel = true
                })
                if alert == "confirm" then
                    lib.callback("haze_simcard:server:buyPhone", false, function(success, msg)
                        lib.notify({
                            title = "Mercado Clandestino",
                            description = msg,
                            type = success and "success" or "error"
                        })
                    end)
                end
            end
        })

        -- Triangulador IMSI
        if shop.sellTracker then
            table.insert(options, {
                title = string.format("Triangulador IMSI de Sinal ($%s)", Config.Tracking.trackerPrice or 7500),
                description = "Dispositivo capaz de escanear antenas ERB para triangular celulares ligados.",
                icon = "fa-solid fa-satellite-dish",
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = "Equipamento Tático",
                        content = string.format("Deseja adquirir o Triangulador IMSI por **$%s**?", Config.Tracking.trackerPrice or 7500),
                        centered = true,
                        cancel = true
                    })
                    if alert == "confirm" then
                        lib.callback("haze_simcard:server:buyTactical", false, function(success, msg)
                            lib.notify({
                                title = "Mercado Clandestino",
                                description = msg,
                                type = success and "success" or "error"
                            })
                        end, "tracker")
                    end
                end
            })
        end

        -- Bloqueador Jammer
        if shop.sellJammer then
            table.insert(options, {
                title = string.format("Bloqueador de Frequência Jammer ($%s)", Config.Tracking.jammerPrice or 5000),
                description = "Emite ruído de frequência que cega trianguladores e grampos.",
                icon = "fa-solid fa-shield-virus",
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = "Equipamento Tático",
                        content = string.format("Deseja adquirir o Bloqueador Jammer por **$%s**?", Config.Tracking.jammerPrice or 5000),
                        centered = true,
                        cancel = true
                    })
                    if alert == "confirm" then
                        lib.callback("haze_simcard:server:buyTactical", false, function(success, msg)
                            lib.notify({
                                title = "Mercado Clandestino",
                                description = msg,
                                type = success and "success" or "error"
                            })
                        end, "jammer")
                    end
                end
            })

            table.insert(options, {
                title = "Recarregar Baterias do Jammer ($300)",
                description = "Substitui as células de lítio de um bloqueador com bateria gasta para 100%.",
                icon = "fa-solid fa-battery-full",
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = "Manutenção Eletrônica",
                        content = "Deseja substituir as baterias do seu Bloqueador por **$300**?",
                        centered = true,
                        cancel = true
                    })
                    if alert == "confirm" then
                        lib.callback("haze_simcard:server:buyTactical", false, function(success, msg)
                            lib.notify({
                                title = "Mercado Clandestino",
                                description = msg,
                                type = success and "success" or "error"
                            })
                        end, "recharge")
                    end
                end
            })
        end
    else
        -- Lojas Oficiais das Operadoras
        table.insert(options, {
            title = "Comprar Aparelho Smartphone",
            description = string.format("Valor: $%s | Aparelho desbloqueado compatível com todas as operadoras", Config.PhonePrice),
            icon = "fa-solid fa-mobile-screen",
            onSelect = function()
                local alert = lib.alertDialog({
                    header = "Confirmação de Compra",
                    content = string.format("Deseja comprar um aparelho celular por **$%s**?", Config.PhonePrice),
                    centered = true,
                    cancel = true
                })
                if alert == "confirm" then
                    lib.callback("haze_simcard:server:buyPhone", false, function(success, msg)
                        lib.notify({
                            title = "Operadora",
                            description = msg,
                            type = success and "success" or "error"
                        })
                    end)
                end
            end
        })

        table.insert(options, {
            title = "Adquirir Novo Chip SIM",
            description = "Ative uma nova linha cadastrada no seu documento estadual",
            icon = "fa-solid fa-sim-card",
            onSelect = function()
                OpenBuySimMenu(shop)
            end
        })

        table.insert(options, {
            title = "Minhas Linhas / 2ª Via / Bloqueio",
            description = "Gerencie suas linhas registradas, emita 2ª via ou bloqueie números perdidos",
            icon = "fa-solid fa-address-book",
            onSelect = function()
                OpenMySimsMenu(shop)
            end
        })

        table.insert(options, {
            title = "Portabilidade Numérica",
            description = string.format("Migre seu número atual para outra operadora (Taxa: $%s)", Config.PortabilityPrice),
            icon = "fa-solid fa-arrow-right-arrow-left",
            onSelect = function()
                OpenPortabilityMenu(shop)
            end
        })
    end

    lib.registerContext({
        id = "haze_simcard_main_shop",
        title = shop.label,
        options = options
    })

    lib.showContext("haze_simcard_main_shop")
end

--- Menu para seleção de operadora e tipo de chip
function OpenBuySimMenu(shop)
    local options = {}

    -- Chips das operadoras disponíveis na loja
    for _, opKey in ipairs(shop.operators or {}) do
        local op = Config.Operators[opKey]
        if op then
            table.insert(options, {
                title = string.format("%s ($%s)", op.label, op.price),
                description = op.description,
                icon = op.icon,
                onSelect = function()
                    OpenNumberTypeMenu(opKey, false, op)
                end
            })
        end
    end

    -- Se a loja permite venda de chip descartável
    if shop.allowBurner then
        table.insert(options, {
            title = string.format("%s ($%s)", Config.Burner.label, Config.Burner.price),
            description = Config.Burner.description,
            icon = "fa-solid fa-mask",
            onSelect = function()
                OpenNumberTypeMenu("burner", true, Config.Burner)
            end
        })
    end

    lib.registerContext({
        id = "haze_simcard_buy_sim",
        title = "Escolha a Operadora",
        menu = "haze_simcard_main_shop",
        options = options
    })

    lib.showContext("haze_simcard_buy_sim")
end

--- Menu para escolher entre número aleatório ou número personalizado
function OpenNumberTypeMenu(opKey, isBurner, opData)
    local options = {
        {
            title = "Número Aleatório Padrão",
            description = string.format("Gerado automaticamente com o prefixo %s ($%s)", opData.prefix or "555", opData.price),
            icon = "fa-solid fa-dice",
            onSelect = function()
                lib.callback("haze_simcard:server:buySim", false, function(success, msg)
                    lib.notify({
                        title = "Chip SIM",
                        description = msg,
                        type = success and "success" or "error"
                    })
                end, opKey, isBurner, nil)
            end
        }
    }

    -- Opção de número customizado apenas para chips registrados
    if not isBurner then
        table.insert(options, {
            title = "Número Personalizado (VIP)",
            description = string.format("Escolha seu próprio número de 6 a 10 dígitos (Taxa: $%s ou Voucher VIP)", Config.CustomNumberPrice),
            icon = "fa-solid fa-gem",
            onSelect = function()
                local input = lib.inputDialog("Ativação de Número VIP", {
                    {
                        type = "input",
                        label = "Número desejado (apenas números, 6 a 10 dígitos)",
                        placeholder = "Ex: 777888",
                        required = true,
                        min = 6,
                        max = 10
                    }
                })
                if input and input[1] then
                    lib.callback("haze_simcard:server:buySim", false, function(success, msg)
                        lib.notify({
                            title = "Chip SIM VIP",
                            description = msg,
                            type = success and "success" or "error"
                        })
                    end, opKey, false, input[1])
                end
            end
        })
    end

    lib.registerContext({
        id = "haze_simcard_number_type",
        title = opData.label,
        menu = "haze_simcard_buy_sim",
        options = options
    })

    lib.showContext("haze_simcard_number_type")
end

--- Menu de gerenciamento de linhas do jogador (2ª via e bloqueio)
function OpenMySimsMenu(shop)
    lib.callback("haze_simcard:server:getPlayerSims", false, function(sims)
        if not sims or #sims == 0 then
            lib.notify({
                title = "Operadora",
                description = "Você não possui nenhuma linha telefônica registrada em seu nome.",
                type = "inform"
            })
            return
        end

        local options = {}
        for _, sim in ipairs(sims) do
            local statusStr = sim.is_blocked == 1 and "[BLOQUEADO]" or "[ATIVO]"
            table.insert(options, {
                title = string.format("%s - %s %s", sim.operator, sim.number, statusStr),
                description = "Clique para emitir 2ª via ou bloquear a linha",
                icon = "fa-solid fa-phone",
                onSelect = function()
                    OpenSimActionMenu(sim, shop)
                end
            })
        end

        lib.registerContext({
            id = "haze_simcard_my_sims",
            title = "Minhas Linhas Registradas",
            menu = "haze_simcard_main_shop",
            options = options
        })

        lib.showContext("haze_simcard_my_sims")
    end)
end

--- Menu de ações para uma linha específica
function OpenSimActionMenu(sim, shop)
    local options = {
        {
            title = "Emitir 2ª Via (Duplicata)",
            description = "Gera um novo chip físico com o mesmo número e reativa a linha.",
            icon = "fa-solid fa-copy",
            onSelect = function()
                local alert = lib.alertDialog({
                    header = "Confirmação de 2ª Via",
                    content = string.format("Deseja emitir uma segunda via para a linha **%s**?\n\n*Nota: Se o chip antigo foi perdido ou roubado, ele será desativado permanentemente.*", sim.number),
                    centered = true,
                    cancel = true
                })
                if alert == "confirm" then
                    lib.callback("haze_simcard:server:duplicateSim", false, function(success, msg)
                        lib.notify({
                            title = "2ª Via de Chip",
                            description = msg,
                            type = success and "success" or "error"
                        })
                    end, sim.number)
                end
            end
        },
        {
            title = "Bloquear Linha",
            description = "Bloqueia a linha e invalida chips físicos antigos imediatamente.",
            icon = "fa-solid fa-ban",
            onSelect = function()
                local alert = lib.alertDialog({
                    header = "Bloqueio de Linha",
                    content = string.format("Tem certeza que deseja bloquear a linha **%s**?", sim.number),
                    centered = true,
                    cancel = true
                })
                if alert == "confirm" then
                    lib.callback("haze_simcard:server:blockSim", false, function(success, msg)
                        lib.notify({
                            title = "Bloqueio de Linha",
                            description = msg,
                            type = success and "success" or "error"
                        })
                    end, sim.number)
                end
            end
        }
    }

    lib.registerContext({
        id = "haze_simcard_sim_actions",
        title = "Linha: " .. sim.number,
        menu = "haze_simcard_my_sims",
        options = options
    })

    lib.showContext("haze_simcard_sim_actions")
end

--- Menu de Portabilidade Numérica
function OpenPortabilityMenu(shop)
    lib.callback("haze_simcard:server:getPlayerSims", false, function(sims)
        if not sims or #sims == 0 then
            lib.notify({
                title = "Portabilidade",
                description = "Você não possui linhas registradas para portabilidade.",
                type = "error"
            })
            return
        end

        local options = {}
        for _, sim in ipairs(sims) do
            table.insert(options, {
                title = string.format("Portar linha %s (%s)", sim.number, sim.operator),
                description = "Clique para selecionar a operadora de destino",
                icon = "fa-solid fa-arrow-right-arrow-left",
                onSelect = function()
                    OpenDestinationOperatorMenu(sim)
                end
            })
        end

        lib.registerContext({
            id = "haze_simcard_portability_list",
            title = "Selecione a Linha",
            menu = "haze_simcard_main_shop",
            options = options
        })

        lib.showContext("haze_simcard_portability_list")
    end)
end

--- Escolhe a operadora de destino para a portabilidade
function OpenDestinationOperatorMenu(sim)
    local options = {}

    for opKey, opData in pairs(Config.Operators) do
        if opData.label ~= sim.operator then
            table.insert(options, {
                title = string.format("Migrar para %s", opData.label),
                description = string.format("Taxa: $%s | %s", Config.PortabilityPrice, opData.description),
                icon = opData.icon,
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = "Confirmar Portabilidade",
                        content = string.format("Deseja transferir a linha **%s** da operadora **%s** para a **%s** por **$%s**?", sim.number, sim.operator, opData.label, Config.PortabilityPrice),
                        centered = true,
                        cancel = true
                    })
                    if alert == "confirm" then
                        lib.callback("haze_simcard:server:portability", false, function(success, msg)
                            lib.notify({
                                title = "Portabilidade Numérica",
                                description = msg,
                                type = success and "success" or "error"
                            })
                        end, sim.number, opKey)
                    end
                end
            })
        end
    end

    lib.registerContext({
        id = "haze_simcard_dest_operator",
        title = "Operadora de Destino",
        menu = "haze_simcard_portability_list",
        options = options
    })

    lib.showContext("haze_simcard_dest_operator")
end

--- Exibe o relatório de consulta investigativa policial
local function ShowPoliceReport(result)
    PlaySoundFrontend(-1, "Event_Message_Purple", "GTAO_FM_Events_Soundset", true)

    local options = {
        {
            title = "Número Consultado",
            description = result.number,
            icon = "fa-solid fa-phone"
        },
        {
            title = "Operadora Responsável",
            description = result.operator,
            icon = "fa-solid fa-tower-cell"
        },
        {
            title = "Proprietário / Titular da Linha",
            description = result.owner,
            icon = "fa-solid fa-id-card",
            onSelect = function()
                lib.setClipboard(result.owner)
                lib.notify({
                    title = "Terminal Policial",
                    description = "Dados do titular copiados para a área de transferência.",
                    type = "success"
                })
            end
        },
        {
            title = "Situação Cadastral",
            description = result.status,
            icon = result.is_burner and "fa-solid fa-triangle-exclamation" or "fa-solid fa-circle-check"
        },
        {
            title = "Status do Sinal em Tempo Real",
            description = result.signal or "Informação indisponível",
            icon = "fa-solid fa-satellite-dish"
        }
    }

    lib.registerContext({
        id = "haze_simcard_police_result",
        title = "Relatório de Telecomunicações",
        options = options
    })

    lib.showContext("haze_simcard_police_result")
end

--- Realiza a consulta policial direta por número
function OpenPoliceLookupDirect(targetNum)
    if not targetNum then return end
    local cleanNum = targetNum:gsub("%D", "")

    if #cleanNum < 6 then
        lib.notify({
            title = "Terminal Policial",
            description = "O número informado é muito curto.",
            type = "error"
        })
        return
    end

    lib.callback("haze_simcard:server:policeLookup", false, function(success, result)
        if not success then
            lib.notify({
                title = "Terminal Policial",
                description = result,
                type = "error"
            })
            return
        end
        ShowPoliceReport(result)
    end, cleanNum)
end

--- Menu de consulta de titular para a polícia
function OpenPoliceLookupMenu()
    local input = lib.inputDialog("Terminal Estadual de Telecomunicações", {
        {
            type = "input",
            label = "Número de Telefone Alvo",
            placeholder = "Ex: 2123456",
            required = true
        }
    })

    if not input or not input[1] then return end
    OpenPoliceLookupDirect(input[1])
end

--- Comando para agentes policiais em serviço
RegisterCommand("consultarchip", function(_, args)
    if args and args[1] then
        OpenPoliceLookupDirect(args[1])
    else
        OpenPoliceLookupMenu()
    end
end, false)

