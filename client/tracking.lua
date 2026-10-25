-- Módulo de Rastreamento Tático (phone_tracker) e Bloqueador (signal_jammer)

local currentTrackBlips = {}
local isTrackingActive = false

--- Export chamado ao usar o item phone_tracker
exports("useTracker", function(data, slot)
    local input = lib.inputDialog("Triangulador IMSI de Sinal", {
        {
            type = "input",
            label = "Número Celular Alvo",
            placeholder = "Ex: 2123456",
            required = true
        }
    })

    if not input or not input[1] then return end
    local targetNumber = input[1]:gsub("%D", "")

    if #targetNumber < 6 then
        lib.notify({
            title = "Triangulador IMSI",
            description = "O número informado deve ter no mínimo 6 dígitos.",
            type = "error"
        })
        return
    end

    -- Animação de calibração da antena
    if not lib.progressBar({
        duration = 3800,
        label = "Varrendo frequências ERB e triangulando sinal...",
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, combat = true },
        anim = {
            dict = "cellphone@",
            clip = "cellphone_text_in"
        },
        prop = {
            model = `prop_cs_hand_radio`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        }
    }) then
        return
    end

    lib.callback("haze_simcard:server:trackNumber", false, function(success, resultData)
        if not success then
            PlaySoundFrontend(-1, "Click_Fail", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
            if resultData == "offline" then
                lib.notify({
                    title = "Triangulador IMSI",
                    description = "Falha na triangulação: O aparelho alvo está DESLIGADO ou fora da área de cobertura.",
                    type = "error"
                })
            elseif resultData == "jammed" then
                lib.notify({
                    title = "Triangulador IMSI",
                    description = "Falha na triangulação: Sinal bloqueado por ruído eletromagnético (Jammer ativo nas proximidades).",
                    type = "error"
                })
            elseif resultData == "invalid_number" then
                lib.notify({
                    title = "Triangulador IMSI",
                    description = "Número não localizado em nenhuma operadora de Los Santos.",
                    type = "error"
                })
            elseif resultData == "rate_limited" then
                lib.notify({
                    title = "Triangulador IMSI",
                    description = "Antena em resfriamento térmico. Aguarde alguns segundos para novo escaneamento.",
                    type = "warning"
                })
            else
                lib.notify({
                    title = "Triangulador IMSI",
                    description = "Não foi possível triangular a frequência do alvo.",
                    type = "error"
                })
            end
            return
        end

        -- Som tático de sinal capturado
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)

        -- Limpa blips anteriores se existirem
        for _, b in ipairs(currentTrackBlips) do
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
        currentTrackBlips = {}
        isTrackingActive = true

        local coords = resultData.coords
        local radius = resultData.radius
        local duration = resultData.duration or 40

        -- 1. Blip de área circular de cobertura da antena ERB
        local areaBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
        SetBlipColour(areaBlip, 1) -- Vermelho
        SetBlipAlpha(areaBlip, 125)
        SetBlipFlashes(areaBlip, true)
        SetBlipFlashInterval(areaBlip, 500)
        table.insert(currentTrackBlips, areaBlip)

        -- 2. Blip de ponto de torre/antena no centro aproximado
        local centerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(centerBlip, 459) -- Torre de telecomunicação
        SetBlipColour(centerBlip, 1)
        SetBlipScale(centerBlip, 0.85)
        SetBlipFlashes(centerBlip, true)
        SetBlipFlashInterval(centerBlip, 1000)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Antena ERB - Alvo Triangulado")
        EndTextCommandSetBlipName(centerBlip)
        table.insert(currentTrackBlips, centerBlip)

        lib.notify({
            title = "Triangulação Estabelecida",
            description = string.format("Sinal capturado por antenas ERB! Área aproximada destacada no mapa por %ss.", duration),
            type = "success",
            duration = 5000
        })

        -- Thread de monitoramento e pings intermediários a cada 12 segundos
        CreateThread(function()
            local elapsed = 0
            local pingInterval = 12

            while isTrackingActive and elapsed < duration do
                Wait(pingInterval * 1000)
                elapsed = elapsed + pingInterval

                if not isTrackingActive then break end

                -- Executa pulso de recalibragem com o servidor
                lib.callback("haze_simcard:server:pingTrackTarget", false, function(pingOk, pingData)
                    if not isTrackingActive then return end

                    if not pingOk then
                        -- Perdeu o sinal (alvo desligou celular ou ativou jammer)
                        isTrackingActive = false
                        for _, b in ipairs(currentTrackBlips) do
                            if DoesBlipExist(b) then RemoveBlip(b) end
                        end
                        currentTrackBlips = {}

                        PlaySoundFrontend(-1, "Click_Fail", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)

                        if pingData == "jammed" then
                            lib.notify({
                                title = "Sinal Interrompido",
                                description = "⚠️ PERDA DE SINAL: O transmissor do alvo foi bloqueado por contra-medidas (Jammer ativado)!",
                                type = "error",
                                duration = 6000
                            })
                        else
                            lib.notify({
                                title = "Sinal Interrompido",
                                description = "⚠️ PERDA DE SINAL: O aparelho celular do alvo foi desligado.",
                                type = "error",
                                duration = 6000
                            })
                        end
                    else
                        -- Atualiza as coordenadas dos blips caso o alvo tenha se movido
                        local newCoords = pingData.coords
                        if DoesBlipExist(areaBlip) then
                            SetBlipCoords(areaBlip, newCoords.x, newCoords.y, newCoords.z)
                        end
                        if DoesBlipExist(centerBlip) then
                            SetBlipCoords(centerBlip, newCoords.x, newCoords.y, newCoords.z)
                        end

                        PlaySoundFrontend(-1, "Beep_Green", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                    end
                end, targetNumber)
            end

            -- Fim do tempo de rastreamento
            if isTrackingActive then
                isTrackingActive = false
                for _, b in ipairs(currentTrackBlips) do
                    if DoesBlipExist(b) then RemoveBlip(b) end
                end
                currentTrackBlips = {}

                lib.notify({
                    title = "Triangulador IMSI",
                    description = "Triangulação expirada. O feixe da antena ERB foi redefinido.",
                    type = "inform"
                })
            end
        end)
    end, targetNumber)
end)

--- Export chamado ao usar o item signal_jammer
exports("useJammer", function(data, slot)
    local slotNum = (type(slot) == "table" and slot.slot) or (type(data) == "table" and data.slot) or slot
    if not slotNum then return end

    PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
    TriggerServerEvent("haze_simcard:server:toggleJammer", slotNum)
end)

--- Evento de reprodução de efeitos sonoros táticos
RegisterNetEvent("haze_simcard:client:playTacticalSound", function(soundType)
    if soundType == "jammer_on" then
        PlaySoundFrontend(-1, "Hack_Success", "DLC_HEIST_BIOLAB_PREP_TRACKING_SOUNDS", true)
    elseif soundType == "jammer_off" then
        PlaySoundFrontend(-1, "Click_Fail", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
    elseif soundType == "intercept_alert" then
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
        Wait(250)
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
    end
end)
