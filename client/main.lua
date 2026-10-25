-- Inicialização do client, criação de blips e evento de playerLoaded

CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        if shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, shop.blip.sprite or 459)
            SetBlipColour(blip, shop.blip.color or 3)
            SetBlipScale(blip, shop.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(shop.blip.name or "Operadora de Telefonia")
            EndTextCommandSetBlipName(blip)
        end
    end
end)

local function OnPlayerReady()
    Wait(2000)
    TriggerServerEvent("haze_simcard:server:onPlayerLoaded")
end

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    OnPlayerReady()
end)

RegisterNetEvent("qbx_core:client:playerLoaded", function()
    OnPlayerReady()
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    OnPlayerReady()
end)
