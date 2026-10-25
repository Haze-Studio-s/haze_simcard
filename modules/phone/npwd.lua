local isServer = IsDuplicityVersion()

local NPWDAdapter = {
    Name = "npwd"
}

if isServer then
    function NPWDAdapter.GetSourceFromNumber(phoneNumber)
        if not phoneNumber then return false end
        -- Busca nos jogadores conectados aquele que possui o numero ativo no state bag
        local players = GetPlayers()
        for i = 1, #players do
            local src = tonumber(players[i])
            local activeNum = Player(src).state.activePhoneNumber
            if activeNum and tostring(activeNum) == tostring(phoneNumber) then
                return src
            end
        end
        return false
    end

    function NPWDAdapter.SetPhoneNumber(source, phoneNumber)
        if not source then return end
        Player(source).state:set("activePhoneNumber", phoneNumber, true)
        TriggerClientEvent("haze_simcard:client:setPhoneSession", source, phoneNumber)
    end

    function NPWDAdapter.ClosePhone(source)
        if not source then return end
        TriggerClientEvent("haze_simcard:client:forceClosePhone", source)
    end

    function NPWDAdapter.ToggleDisabled(source, state)
        if not source then return end
        TriggerClientEvent("haze_simcard:client:setPhoneDisabled", source, state)
    end
else
    -- Client-side
    function NPWDAdapter.IsOpen()
        local success, isVisible = pcall(function()
            return exports['npwd']:isVisible()
        end)
        return success and isVisible or false
    end

    function NPWDAdapter.ToggleOpen(state)
        pcall(function()
            if state then
                exports['npwd']:openPhone()
            else
                exports['npwd']:closePhone()
            end
        end)
    end

    function NPWDAdapter.ToggleDisabled(state)
        pcall(function()
            if exports['npwd'].setPhoneDisabled then
                exports['npwd']:setPhoneDisabled(state)
            end
        end)
    end

    function NPWDAdapter.ClosePhone()
        pcall(function()
            exports['npwd']:closePhone()
        end)
    end

    function NPWDAdapter.SetPhoneNumber(phoneNumber)
        LocalPlayer.state:set("activePhoneNumber", phoneNumber, true)
        pcall(function()
            if exports['npwd'].setPhoneNumber then
                exports['npwd']:setPhoneNumber(tostring(phoneNumber))
            end
        end)
    end
end

PhoneBridge.RegisterAdapter("npwd", NPWDAdapter)
