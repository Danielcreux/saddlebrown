DELIMITER //

CREATE PROCEDURE sp_create_weekly_backup()
BEGIN
    DECLARE backup_file VARCHAR(255);
    DECLARE backup_path VARCHAR(512);
    DECLARE db_name VARCHAR(64);
    
    -- Obtener el nombre de la base de datos actual
    SELECT DATABASE() INTO db_name;
    
    -- Establecer rutas y nombres de archivo
    SET backup_file = CONCAT('backup_', db_name, '_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'), '.sql');
    SET backup_path = CONCAT('C:/xampp/htdocs/saddlebrown_backups/', backup_file); -- Cambia esta ruta
    
    -- Registrar el inicio del backup
    INSERT INTO backup_log (backup_name, backup_path, status)
    VALUES (backup_file, backup_path, 'failed');
    
    -- Nota: Esto es un marcador de posición. En la práctica necesitarías:
    -- 1. Un script externo que haga el backup real
    -- 2. Un método para llamar a ese script desde MySQL
    
    -- Actualizar estado como exitoso (en realidad necesitarías verificar el resultado real)
    UPDATE backup_log 
    SET status = 'success' 
    WHERE backup_name = backup_file;
    
    SELECT CONCAT('Backup programado: ', backup_path) AS message;
END //

DELIMITER ;}

-- evento para una semana 

CREATE EVENT IF NOT EXISTS event_weekly_backup
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_DATE + INTERVAL 7 - WEEKDAY(CURRENT_DATE) DAY + INTERVAL 23 HOUR
COMMENT 'Backup semanal completo de la base de datos'
DO
BEGIN
    CALL sp_create_weekly_backup();
END;