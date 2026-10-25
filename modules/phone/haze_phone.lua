local isServer = IsDuplicityVersion()

local HazeAdapter = {
    Name = "haze_phone"
}

if isServer then
    function HazeAdapter.GetSourceFromNumber(phoneNumber)
        if not phoneNumber then return false end
        local success, result = pcall(function()
            return exports['haze_phone']:GetSourceFromNumber(tostring(phoneNumber))
        end)
        if success and result then return result end

        -- Fallback: Tenta como número inteiro
        local success2, result2 = pcall(function()
            return exports['haze_phone']:GetSourceFromNumber(tonumber(phoneNumber))
        end)
        return (success2 and result2) or false
    end

    function HazeAdapter.SetPhoneNumber(source, phoneNumber)
        if not source then return end
        Player(source).state:set("activePhoneNumber", phoneNumber, true)
        TriggerClientEvent("haze_simcard:client:setPhoneSession", source, phoneNumber)
    end

    function HazeAdapter.ClosePhone(source)
        if not source then return end
        TriggerClientEvent("haze_simcard:client:forceClosePhone", source)
    end

    function HazeAdapter.ToggleDisabled(source, state)
        if not source then return end
        TriggerClientEvent("haze_simcard:client:setPhoneDisabled", source, state)
    end
else
    -- Client-side
    function HazeAdapter.IsOpen()
        local success, isOpen = pcall(function()
            return exports['haze_phone']:IsOpen()
        end)
        return success and isOpen or false
    end

    function HazeAdapter.ToggleOpen(state)
        pcall(function()
            exports['haze_phone']:ToggleOpen(state)
        end)
    end

    function HazeAdapter.ToggleDisabled(state)
        pcall(function()
            exports['haze_phone']:ToggleDisabled(state)
        end)
    end

    function HazeAdapter.ClosePhone()
        pcall(function()
            if exports['haze_phone']:IsOpen() then
                exports['haze_phone']:ToggleOpen(false)
            end
            exports['haze_phone']:ToggleDisabled(true)
        end)
    end

    function HazeAdapter.SetPhoneNumber(phoneNumber)
        LocalPlayer.state:set("activePhoneNumber", phoneNumber, true)
        if _G.SetPhone then
            if phoneNumber and phoneNumber ~= 0 then
                _G.SetPhone(tostring(phoneNumber), true)
            else
                _G.SetPhone(nil, true)
            end
        end
    end
end

PhoneBridge.RegisterAdapter("haze_phone", HazeAdapter)

