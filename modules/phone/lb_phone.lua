local isServer = IsDuplicityVersion()

local LBAdapter = {
    Name = "lb_phone"
}

if isServer then
    function LBAdapter.GetSourceFromNumber(phoneNumber)
        if not phoneNumber then return false end
        local success, result = pcall(function()
            return exports['lb-phone']:GetSourceFromNumber(tostring(phoneNumber))
        end)
        if success and result then return result end

        local success2, result2 = pcall(function()
            return exports['lb-phone']:GetSourceFromNumber(tonumber(phoneNumber))
        end)
        return (success2 and result2) or false
    end

    function LBAdapter.SetPhoneNumber(source, phoneNumber)
        if not source then return end
        Player(source).state:set("activePhoneNumber", phoneNumber, true)
        TriggerClientEvent("haze_simcard:client:setPhoneSession", source, phoneNumber)
    end

    function LBAdapter.ClosePhone(source)
        if not source then return end
        TriggerClientEvent("haze_simcard:client:forceClosePhone", source)
    end

    function LBAdapter.ToggleDisabled(source, state)
        if not source then return end
        TriggerClientEvent("haze_simcard:client:setPhoneDisabled", source, state)
    end
else
    -- Client-side
    function LBAdapter.IsOpen()
        local success, isOpen = pcall(function()
            return exports['lb-phone']:IsOpen()
        end)
        return success and isOpen or false
    end

    function LBAdapter.ToggleOpen(state)
        pcall(function()
            exports['lb-phone']:ToggleOpen(state)
        end)
    end

    function LBAdapter.ToggleDisabled(state)
        pcall(function()
            exports['lb-phone']:ToggleDisabled(state)
        end)
    end

    function LBAdapter.ClosePhone()
        pcall(function()
            if exports['lb-phone']:IsOpen() then
                exports['lb-phone']:ToggleOpen(false)
            end
            exports['lb-phone']:ToggleDisabled(true)
        end)
    end

    function LBAdapter.SetPhoneNumber(phoneNumber)
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

PhoneBridge.RegisterAdapter("lb_phone", LBAdapter)

