PhoneBridge = {}
PhoneBridge.Active = nil
PhoneBridge.Adapters = {}

local isServer = IsDuplicityVersion()

--- Registra um adaptador de telefone
---@param name string
---@param adapter table
function PhoneBridge.RegisterAdapter(name, adapter)
    PhoneBridge.Adapters[name] = adapter
end

--- Detecta dinamicamente ou define o adaptador de telefone ativo
---@return table|nil
function PhoneBridge.GetActive()
    if PhoneBridge.Active then
        return PhoneBridge.Active
    end

    local configured = Config.Phone or 'auto'

    if configured ~= 'auto' and PhoneBridge.Adapters[configured] then
        PhoneBridge.Active = PhoneBridge.Adapters[configured]
        return PhoneBridge.Active
    end

    -- Detecção automática por prioridade
    if GetResourceState('haze_phone') == 'started' or GetResourceState('haze_phone') == 'starting' then
        PhoneBridge.Active = PhoneBridge.Adapters['haze_phone']
    elseif GetResourceState('lb-phone') == 'started' or GetResourceState('lb-phone') == 'starting' then
        PhoneBridge.Active = PhoneBridge.Adapters['lb_phone']
    elseif GetResourceState('npwd') == 'started' or GetResourceState('npwd') == 'starting' then
        PhoneBridge.Active = PhoneBridge.Adapters['npwd']
    else
        -- Fallback padrão para haze_phone
        PhoneBridge.Active = PhoneBridge.Adapters['haze_phone']
    end

    return PhoneBridge.Active
end

-- Métodos públicos da Bridge Universal

function PhoneBridge.SetPhoneNumber(source, phoneNumber)
    local adapter = PhoneBridge.GetActive()
    if adapter and adapter.SetPhoneNumber then
        return adapter.SetPhoneNumber(source, phoneNumber)
    end
end

function PhoneBridge.ToggleOpen(source, state)
    local adapter = PhoneBridge.GetActive()
    if adapter and adapter.ToggleOpen then
        return adapter.ToggleOpen(source, state)
    end
end

function PhoneBridge.ToggleDisabled(source, state)
    local adapter = PhoneBridge.GetActive()
    if adapter and adapter.ToggleDisabled then
        return adapter.ToggleDisabled(source, state)
    end
end

function PhoneBridge.IsOpen(source)
    local adapter = PhoneBridge.GetActive()
    if adapter and adapter.IsOpen then
        return adapter.IsOpen(source)
    end
    return false
end

function PhoneBridge.GetSourceFromNumber(phoneNumber)
    local adapter = PhoneBridge.GetActive()
    if adapter and adapter.GetSourceFromNumber then
        return adapter.GetSourceFromNumber(phoneNumber)
    end
    return false
end

function PhoneBridge.ClosePhone(source)
    local adapter = PhoneBridge.GetActive()
    if adapter and adapter.ClosePhone then
        return adapter.ClosePhone(source)
    end
end
