-- Definições de itens para o ox_inventory (data/items.lua)
return {
    -- Chips SIM das Operadoras Oficiais
    ["sim_badger"] = {
        label = "Chip SIM - Badger Wireless",
        weight = 10,
        stack = false,
        consume = 0,
        description = "Linha popular da Badger Wireless. Conectando Los Santos desde 1995.",
        client = {
            export = "haze_simcard.useSimCard"
        }
    },
    ["sim_whiz"] = {
        label = "Chip SIM - Whiz Mobile",
        weight = 10,
        stack = false,
        consume = 0,
        description = "Linha 5G de alta velocidade da Whiz Mobile com cobertura estadual.",
        client = {
            export = "haze_simcard.useSimCard"
        }
    },
    ["sim_eyefind"] = {
        label = "Chip SIM - EyeFind Telecom",
        weight = 10,
        stack = false,
        consume = 0,
        description = "Linha corporativa com protecao anti-triangulacao de sinal.",
        client = {
            export = "haze_simcard.useSimCard"
        }
    },
    ["sim_bittersweet"] = {
        label = "Chip SIM - Bittersweet Mobile",
        weight = 10,
        stack = false,
        consume = 0,
        description = "Linha criptografada com sensor de interceptacao e alerta de grampo.",
        client = {
            export = "haze_simcard.useSimCard"
        }
    },

    -- Chip Clandestino / Descartavel
    ["sim_burner"] = {
        label = "AnonSIM Descartavel",
        weight = 10,
        stack = false,
        consume = 0,
        description = "Linha pre-paga sem registro de titular. Autodestruicao programada para 24h.",
        client = {
            export = "haze_simcard.useSimCard"
        }
    },
    ["burned_sim"] = {
        label = "Chip SIM Queimado",
        weight = 10,
        stack = true,
        consume = 0,
        description = "Circuito torrado e inutilizavel. Lixo eletronico."
    },

    -- Voucher de Numero Personalizado
    ["custom_number_card"] = {
        label = "Voucher Numero VIP",
        weight = 5,
        stack = true,
        consume = 0,
        description = "Permite escolher um numero de telefone personalizado de 6 a 10 digitos na operadora."
    },

    -- Itens Taticos (Rastreamento & Contra-Medidas)
    ["phone_tracker"] = {
        label = "Triangulador IMSI de Sinal",
        weight = 800,
        stack = false,
        consume = 0,
        description = "Dispositivo tatico capaz de triangular antenas ERB para localizar celulares ligados.",
        client = {
            export = "haze_simcard.useTracker"
        }
    },
    ["signal_jammer"] = {
        label = "Bloqueador de Frequencia Portatil",
        weight = 600,
        stack = false,
        consume = 0,
        description = "Emite ruido eletromagnetico que blinda o portador contra triangulacoes e grampos.",
        client = {
            export = "haze_simcard.useJammer"
        }
    }
}
