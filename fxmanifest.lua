fx_version 'cerulean'
games {'gta5'}
lua54 'yes'

name 'haze_simcard'
author 'Haze Studios'
description 'Sistema de Chips SIM Fisicos, Operadoras Lore-Friendly, Rastreamento e Telefone Descartavel'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'modules/phone/bridge.lua',
    'modules/phone/haze_phone.lua',
    'modules/phone/lb_phone.lua',
    'modules/phone/npwd.lua',
    'server/database.lua',
    'server/security.lua',
    'server/sim_manager.lua',
    'server/burner.lua',
    'server/tracking.lua',
    'server/main.lua'
}

client_scripts {
    'modules/phone/bridge.lua',
    'modules/phone/haze_phone.lua',
    'modules/phone/lb_phone.lua',
    'modules/phone/npwd.lua',
    'client/phone_controls.lua',
    'client/shop.lua',
    'client/tracking.lua',
    'client/main.lua'
}

files {
    'locales/*.json',
    'sql/schema.sql',
    'data/items.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'qbx_core'
}
