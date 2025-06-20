DELIMITER //

CREATE TRIGGER before_lineas_pedido_insert
BEFORE INSERT ON lineas_pedido
FOR EACH ROW
BEGIN
    DECLARE v_stock_actual DECIMAL(10,2);
    DECLARE v_error_message VARCHAR(255);
    
    -- Obtener el stock actual
    SELECT stock_actual INTO v_stock_actual
    FROM productos
    WHERE producto_id = NEW.producto_id;
    
    -- Verificar stock suficiente
    IF v_stock_actual < NEW.cantidad THEN
        -- Construir mensaje de error
        SET v_error_message = CONCAT('Stock insuficiente para el producto ID ', NEW.producto_id, 
                                   '. Stock actual: ', v_stock_actual, 
                                   ', Cantidad solicitada: ', NEW.cantidad);
        
        -- Lanzar error
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_error_message;
    END IF;
END //

DELIMITER ;