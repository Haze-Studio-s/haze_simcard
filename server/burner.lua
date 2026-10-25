BurnerManager = {}

--- Rotina assíncrona periódica para expirar chips descartáveis no servidor
CreateThread(function()
    while true do
        Wait(2 * 60 * 1000) -- Executa a cada 2 minutos
        local expiredList = Database.GetExpiredBurners()
        if expiredList and #expiredList > 0 then
            for i = 1, #expiredList do
                local number = expiredList[i].number
                local activeSrc = PhoneBridge.GetSourceFromNumber(number)

                if activeSrc then
                    PhoneBridge.ClosePhone(activeSrc)
                    TriggerClientEvent("haze_simcard:client:forceTurnOffPhone", activeSrc)

                    -- Busca e limpa o celular do jogador ativo
                    local phones = exports.ox_inventory:Search(activeSrc, "slots", Config.PhoneItem)
                    if phones then
                        for _, p in pairs(phones) do
                            local meta = p.metadata or {}
                            if tostring(meta.phone_number) == tostring(number) then
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
                                exports.ox_inventory:SetMetadata(activeSrc, p.slot, meta)
                                exports.ox_inventory:AddItem(activeSrc, Config.Burner.burnedItem, 1)
                                break
                            end
                        end
                    end

                    TriggerClientEvent("ox_lib:notify", activeSrc, {
                        title = "AnonSIM Descartável",
                        description = "⚠️ Seu chip descartável expirou após 24 horas e os circuitos foram destruídos.",
                        type = "error",
                        duration = 7000
                    })
                end

                -- Apaga o número permanentemente do banco
                Database.DeleteSim(number)
            end
        end
    end
end)

--- Valida se um chip descartável ainda está dentro da validade
---@param metadata table
---@return boolean
function BurnerManager.IsExpired(metadata)
    if not metadata or not metadata.is_burner then return false end
    if metadata.expires_at and os.time() >= metadata.expires_at then
        return true
    end
    return false
end

--- Transforma um chip burner expirado em lixo eletrônico (burned_sim)
---@param source number
---@param slot number
function BurnerManager.BurnItem(source, slot)
    exports.ox_inventory:RemoveItem(source, Config.Burner.item, 1, nil, slot)
    exports.ox_inventory:AddItem(source, Config.Burner.burnedItem, 1, {
        description = "Circuito queimado permanentemente por expiração de tempo (24h)."
    })
end
