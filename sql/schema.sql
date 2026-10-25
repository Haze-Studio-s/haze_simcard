-- Schema do haze_simcard
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

-- Query de migracao automatica e segura de telefones pre-existentes no servidor
-- Transforma numeros ja existentes em phone_phones em chips da Badger Wireless sem perda de dados
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
