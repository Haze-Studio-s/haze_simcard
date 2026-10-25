Database = {}

local function InitializeDatabase()
    local createTableQuery = [[
        CREATE TABLE IF NOT EXISTS `haze_simcards` (
            `id` VARCHAR(50) NOT NULL,
            `number` VARCHAR(20) NOT NULL,
            `operator` VARCHAR(30) NOT NULL DEFAULT 'Badger Wireless',
            `owner` VARCHAR(50) NULL DEFAULT NULL,
            `is_burner` TINYINT(1) NOT NULL DEFAULT 0,
            `is_blocked` TINYINT(1) NOT NULL DEFAULT 0,
            `expires_at` INT NULL DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_sim_number` (`number`),
            KEY `idx_owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    MySQL.query(createTableQuery, {}, function(result)
        -- Query de migração automática e retrocompatibilidade com telefones já existentes
        local migrationQuery = [[
            INSERT IGNORE INTO `haze_simcards` (`id`, `number`, `operator`, `owner`, `is_burner`, `is_blocked`, `created_at`)
            SELECT 
                CONCAT('MIG-', SUBSTRING(MD5(p.phone_number), 1, 8)),
                p.phone_number,
                'Badger Wireless',
                p.owner_id,
                0,
                0,
                p.last_seen
            FROM `phone_phones` p
            WHERE p.phone_number NOT IN (SELECT number FROM `haze_simcards`);
        ]]

        MySQL.query(migrationQuery, {}, function(migResult)
            if migResult and migResult.affectedRows and migResult.affectedRows > 0 then
                print(string.format('^2[haze_simcard]^7 Migracao concluida: ^3%s^7 telefones antigos convertidos para Badger Wireless com sucesso!^7', migResult.affectedRows))
            end
        end)
    end)
end

MySQL.ready(function()
    InitializeDatabase()
end)

--- Busca um chip pelo número
---@param number string|number
---@return table|nil
function Database.GetSimByNumber(number)
    return MySQL.single.await("SELECT * FROM `haze_simcards` WHERE `number` = ? LIMIT 1", { tostring(number) })
end

--- Busca todos os chips registrados de um proprietário (CitizenID)
---@param owner string
---@return table
function Database.GetPlayerSims(owner)
    local result = MySQL.query.await("SELECT * FROM `haze_simcards` WHERE `owner` = ? AND `is_burner` = 0 ORDER BY `created_at` DESC", { owner })
    return result or {}
end

--- Verifica se um número já está registrado no banco
---@param number string|number
---@return boolean
function Database.IsNumberTaken(number)
    local count = MySQL.scalar.await("SELECT COUNT(*) FROM `haze_simcards` WHERE `number` = ?", { tostring(number) })
    return (count and count > 0) or false
end

--- Cria um novo chip SIM no banco de dados
---@param data table
---@return boolean
function Database.CreateSim(data)
    local query = [[
        INSERT INTO `haze_simcards` (`id`, `number`, `operator`, `owner`, `is_burner`, `is_blocked`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]]
    local insertId = MySQL.insert.await(query, {
        data.id,
        tostring(data.number),
        data.operator or 'Badger Wireless',
        data.owner or nil,
        data.is_burner and 1 or 0,
        0,
        data.expires_at or nil
    })

    -- Sincroniza com phone_phones para compatibilidade instantânea com haze_phone e lb-phone
    pcall(function()
        MySQL.query([[
            INSERT INTO `phone_phones` (`id`, `owner_id`, `phone_number`)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `phone_number` = `phone_number`
        ]], {
            tostring(data.number),
            data.owner or tostring(data.number),
            tostring(data.number)
        })
    end)

    return insertId ~= nil
end

--- Atualiza a operadora de um chip (Portabilidade Numérica)
---@param number string|number
---@param newOperator string
---@return boolean
function Database.UpdateOperator(number, newOperator)
    local affected = MySQL.update.await("UPDATE `haze_simcards` SET `operator` = ? WHERE `number` = ?", {
        newOperator,
        tostring(number)
    })
    return affected and affected > 0
end

--- Bloqueia um chip SIM alterando seu ID único (invalida chips físicos antigos)
---@param number string|number
---@param newId string
---@return boolean
function Database.BlockAndRotateId(number, newId)
    local affected = MySQL.update.await("UPDATE `haze_simcards` SET `id` = ?, `is_blocked` = 1 WHERE `number` = ?", {
        newId,
        tostring(number)
    })
    return affected and affected > 0
end

--- Reativa um chip ao emitir segunda via
---@param number string|number
---@param newId string
---@return boolean
function Database.UnblockAndAssignId(number, newId)
    local affected = MySQL.update.await("UPDATE `haze_simcards` SET `id` = ?, `is_blocked` = 0 WHERE `number` = ?", {
        newId,
        tostring(number)
    })
    return affected and affected > 0
end

--- Exclui/Cancela permanentemente uma linha telefônica
---@param number string|number
---@return boolean
function Database.DeleteSim(number)
    local affected = MySQL.update.await("DELETE FROM `haze_simcards` WHERE `number` = ?", { tostring(number) })
    return affected and affected > 0
end

--- Busca chips descartáveis com prazo de validade expirado
---@return table
function Database.GetExpiredBurners()
    local now = os.time()
    local result = MySQL.query.await("SELECT `number` FROM `haze_simcards` WHERE `is_burner` = 1 AND `expires_at` IS NOT NULL AND `expires_at` <= ?", { now })
    return result or {}
end
