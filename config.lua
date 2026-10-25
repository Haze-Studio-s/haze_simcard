Config = {}

-- Modo de detecção do telefone: 'auto', 'haze_phone', 'lb_phone', 'npwd'
Config.Phone = 'auto'

-- Tipo de conta preferencial para pagamentos: 'money', 'bank', ou 'both' (debita de onde houver saldo)
Config.Account = 'both'

-- Configuração do item de celular físico
Config.PhoneItem = 'phone'
Config.PhonePrice = 500

-- Tempo padrão de duração do chip descartável (24 horas em segundos)
Config.BurnerDuration = 86400

-- Cargos com acesso à consulta policial de titulares
Config.PoliceJobs = {
    ['police'] = 0,
    ['bcso'] = 0,
    ['sasp'] = 0,
    ['fib'] = 0,
    ['state'] = 0
}

-- Configurações das Operadoras Lore-Friendly de GTA
Config.Operators = {
    ['badger'] = {
        name = 'badger',
        label = 'Badger Wireless',
        item = 'sim_badger',
        price = 100,
        duplicatePrice = 80,
        prefix = '2',
        slogan = 'Conectando Los Santos desde 1995.',
        description = 'A operadora mais popular e acessivel da cidade. Sinal basico confiavel.',
        icon = 'fa-solid fa-tower-cell',
        color = '#38bdf8'
    },
    ['whiz'] = {
        name = 'whiz',
        label = 'Whiz Mobile',
        item = 'sim_whiz',
        price = 350,
        duplicatePrice = 150,
        prefix = '3',
        slogan = 'Fast, Reliable, Whiz.',
        description = 'Cobertura estadual 5G de alta velocidade. Sinal estavel em qualquer canto do mapa.',
        icon = 'fa-solid fa-bolt',
        color = '#f59e0b'
    },
    ['eyefind'] = {
        name = 'eyefind',
        label = 'EyeFind Telecom',
        item = 'sim_eyefind',
        price = 250,
        duplicatePrice = 120,
        prefix = '7',
        slogan = 'Rede Corporativa e de Servicos Governamentais.',
        description = 'Blindagem contra rastreadores amadores. Triangulacoes sofrem 50% de dispersao.',
        icon = 'fa-solid fa-shield-halved',
        color = '#10b981',
        policeDiscount = true, -- Gratuito para policiais em servico
        antiTrackerBonus = 150.0 -- Aumenta o raio de dispersao da triangulacao
    },
    ['bittersweet'] = {
        name = 'bittersweet',
        label = 'Bittersweet Mobile',
        item = 'sim_bittersweet',
        price = 750,
        duplicatePrice = 300,
        prefix = '9',
        slogan = 'Privacidade Absoluta e Tecnologia Criptografica.',
        description = 'Emite alertas discretos ao usuario se o sinal sofrer tentativa de interceptacao.',
        icon = 'fa-solid fa-user-secret',
        color = '#a855f7',
        notifyOnIntercept = true
    }
}

-- Chip Clandestino / Descartavel
Config.Burner = {
    label = 'AnonSIM Descartavel',
    item = 'sim_burner',
    burnedItem = 'burned_sim',
    price = 200,
    prefix = '6',
    duration = 86400, -- 24h
    description = 'Chip pre-pago sem registro de titular. Queima automaticamente apos 24 horas.'
}

-- Custos de Servicos Especiais
Config.PortabilityPrice = 500
Config.CustomNumberPrice = 2500
Config.CustomNumberItem = 'custom_number_card'

-- Sistema de Rastreamento & Contra-Medidas
Config.Tracking = {
    trackerItem = 'phone_tracker',
    jammerItem = 'signal_jammer',
    trackerPrice = 7500,
    jammerPrice = 5000,
    duration = 40, -- Duracao do blip de area em segundos
    baseRadius = 180.0, -- Raio da area circular de busca em metros
    refreshInterval = 10, -- Segundos entre atualizacoes de posicao
    jammerDrainInterval = 60, -- Segundos para drenar 1% de bateria do jammer
}

-- Lojas Oficiais das Operadoras
Config.Shops = {
    {
        id = 'telecom_central',
        label = 'Centro de Telecomunicacoes de Los Santos',
        coords = vector4(-1082.94, -245.92, 37.76, 210.0),
        pedModel = 'ig_molly',
        blip = {
            sprite = 459,
            color = 3,
            scale = 0.8,
            name = 'Operadora de Telefonia'
        },
        operators = { 'badger', 'whiz', 'eyefind' },
        allowBurner = false
    },
    {
        id = 'bittersweet_boutique',
        label = 'Bittersweet Premium Boutique',
        coords = vector4(-630.56, -229.43, 38.06, 120.0),
        pedModel = 'a_m_y_smartcaspat_01',
        blip = {
            sprite = 459,
            color = 27,
            scale = 0.8,
            name = 'Bittersweet Mobile'
        },
        operators = { 'bittersweet', 'whiz' },
        allowBurner = false
    },
    {
        id = 'paleto_telecom',
        label = 'Posto de Atendimento Paleto Bay',
        coords = vector4(104.93, 6625.33, 31.79, 225.0),
        pedModel = 'a_f_y_business_01',
        blip = {
            sprite = 459,
            color = 3,
            scale = 0.7,
            name = 'Posto de Telecomunicacoes'
        },
        operators = { 'badger', 'whiz' },
        allowBurner = false
    },
    {
        id = 'blackmarket_burner',
        label = 'Mercador Clandestino de Comunicacoes',
        coords = vector4(749.72, -1399.07, 26.54, 90.0), -- Beco em Cypress Flats
        pedModel = 'g_m_m_armboss_01',
        blip = nil, -- Sem blip no mapa (clandestino)
        operators = {},
        allowBurner = true,
        sellJammer = true,
        sellTracker = true
    }
}

-- Terminais de Investigação Policial nas Delegacias e Órgãos de Segurança
Config.PoliceTerminals = {
    {
        id = 'mrpd_terminal',
        label = 'Terminal de Telecomunicações - MRPD',
        coords = vector3(441.87, -981.82, 30.69),
        size = vec3(1.2, 1.2, 1.5),
        heading = 180.0
    },
    {
        id = 'davis_terminal',
        label = 'Terminal de Telecomunicações - Davis Sheriff',
        coords = vector3(363.85, -1588.66, 29.29),
        size = vec3(1.2, 1.2, 1.5),
        heading = 230.0
    },
    {
        id = 'sandy_terminal',
        label = 'Terminal de Telecomunicações - Sandy Sheriff',
        coords = vector3(1853.25, 3687.95, 34.27),
        size = vec3(1.2, 1.2, 1.5),
        heading = 210.0
    },
    {
        id = 'paleto_terminal',
        label = 'Terminal de Telecomunicações - Paleto Sheriff',
        coords = vector3(-449.19, 6012.72, 31.72),
        size = vec3(1.2, 1.2, 1.5),
        heading = 270.0
    },
    {
        id = 'fib_terminal',
        label = 'Terminal de Telecomunicações - FIB Headquarters',
        coords = vector3(136.18, -749.25, 262.85),
        size = vec3(1.2, 1.2, 1.5),
        heading = 250.0
    }
}

