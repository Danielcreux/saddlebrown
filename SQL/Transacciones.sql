-- Procedimiento Almacenado Completo para Crear Pedidos
DELIMITER //

CREATE PROCEDURE sp_crear_pedido_completo(
    -- Parámetros del cliente
    IN p_codigo_cliente VARCHAR(20),
    IN p_nombre_cliente VARCHAR(100),
    IN p_tipo_cliente ENUM('Persona', 'Empresa'),
    IN p_documento_identidad VARCHAR(20),
    IN p_direccion TEXT,
    IN p_ciudad VARCHAR(50),
    IN p_codigo_postal VARCHAR(10),
    IN p_telefono VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_limite_credito DECIMAL(10,2),
    
    -- Parámetros del pedido
    IN p_codigo_pedido VARCHAR(20),
    IN p_fecha_entrega_prevista DATE,
    IN p_metodo_pago ENUM('Efectivo', 'Tarjeta', 'Transferencia', 'Bizum'),
    IN p_notas_pedido TEXT,
    IN p_direccion_entrega TEXT,
    
    -- Parámetros de las líneas de pedido (como JSON)
    IN p_lineas_pedido JSON
)
BEGIN
    DECLARE v_cliente_id INT;
    DECLARE v_pedido_id INT;
    DECLARE v_linea_index INT DEFAULT 0;
    DECLARE v_lineas_count INT;
    DECLARE v_producto_id INT;
    DECLARE v_cantidad DECIMAL(10,2);
    DECLARE v_precio_unitario DECIMAL(10,2);
    DECLARE v_descuento DECIMAL(5,2);
    DECLARE v_notas_linea TEXT;
    DECLARE v_iva_percent DECIMAL(5,2);
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0;
    DECLARE v_total_iva DECIMAL(12,2) DEFAULT 0;
    DECLARE v_total_pedido DECIMAL(12,2) DEFAULT 0;
    DECLARE v_linea_json JSON;
    DECLARE v_error_msg TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    -- Validación básica de parámetros
    IF p_lineas_pedido IS NULL OR JSON_LENGTH(p_lineas_pedido) = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Debe proporcionar al menos una línea de pedido';
    END IF;
    
    IF p_email NOT LIKE '%@%.%' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'El formato del email no es válido';
    END IF;
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- 1. Crear el cliente (o usar existente si el documento ya existe)
    IF EXISTS (SELECT 1 FROM clientes WHERE documento_identidad = p_documento_identidad) THEN
        SELECT cliente_id INTO v_cliente_id 
        FROM clientes 
        WHERE documento_identidad = p_documento_identidad
        LIMIT 1;
        
        UPDATE clientes SET
            nombre = p_nombre_cliente,
            direccion = p_direccion,
            ciudad = p_ciudad,
            codigo_postal = p_codigo_postal,
            telefono = p_telefono,
            email = p_email,
            limite_credito = p_limite_credito,
            fecha_ultima_actualizacion = CURRENT_TIMESTAMP
        WHERE cliente_id = v_cliente_id;
    ELSE
        INSERT INTO clientes (
            codigo_cliente, nombre, tipo, documento_identidad,
            direccion, ciudad, codigo_postal, telefono,
            email, limite_credito
        ) VALUES (
            p_codigo_cliente, p_nombre_cliente, p_tipo_cliente, p_documento_identidad,
            p_direccion, p_ciudad, p_codigo_postal, p_telefono,
            p_email, p_limite_credito
        );
        
        SET v_cliente_id = LAST_INSERT_ID();
    END IF;
    
    -- 2. Crear el pedido
    INSERT INTO pedidos (
        codigo_pedido, cliente_id, fecha_entrega_prevista,
        estado, metodo_pago, notas, direccion_entrega
    ) VALUES (
        p_codigo_pedido, v_cliente_id, p_fecha_entrega_prevista,
        'Pendiente', p_metodo_pago, p_notas_pedido, 
        COALESCE(p_direccion_entrega, p_direccion)
    );
    
    SET v_pedido_id = LAST_INSERT_ID();
    SET v_lineas_count = JSON_LENGTH(p_lineas_pedido);
    
    -- 3. Procesar cada línea de pedido
    WHILE v_linea_index < v_lineas_count DO
        SET v_linea_json = JSON_EXTRACT(p_lineas_pedido, CONCAT('$[', v_linea_index, ']'));
        
        -- Extraer valores con manejo de NULLs
        SET v_producto_id = IFNULL(JSON_UNQUOTE(JSON_EXTRACT(v_linea_json, '$.producto_id')), 0);
        SET v_cantidad = IFNULL(JSON_EXTRACT(v_linea_json, '$.cantidad'), 0);
        SET v_precio_unitario = IFNULL(JSON_EXTRACT(v_linea_json, '$.precio_unitario'), 0);
        SET v_descuento = IFNULL(JSON_EXTRACT(v_linea_json, '$.descuento'), 0);
        SET v_notas_linea = IFNULL(JSON_UNQUOTE(JSON_EXTRACT(v_linea_json, '$.notas')), '');
        
        -- Validar producto
        SELECT iva_percent INTO v_iva_percent FROM productos WHERE producto_id = v_producto_id;
        
        IF v_iva_percent IS NULL THEN
            SET v_error_msg = 'Producto no encontrado con ID: ';
            SET v_error_msg = CONCAT(v_error_msg, v_producto_id);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
        END IF;
        
        -- Validar stock
        IF EXISTS (
            SELECT 1 FROM productos 
            WHERE producto_id = v_producto_id AND stock_actual < v_cantidad
        ) THEN
            SET v_error_msg = 'Stock insuficiente para el producto ID: ';
            SET v_error_msg = CONCAT(v_error_msg, v_producto_id);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
        END IF;
        
        -- Insertar línea
        INSERT INTO lineas_pedido (
            pedido_id, producto_id, cantidad,
            precio_unitario, iva_percent, descuento, notas
        ) VALUES (
            v_pedido_id, v_producto_id, v_cantidad,
            v_precio_unitario, v_iva_percent, v_descuento, v_notas_linea
        );
        
        -- Actualizar cálculos
        SET v_subtotal = v_subtotal + (v_cantidad * v_precio_unitario * (1 - v_descuento/100));
        SET v_total_iva = v_total_iva + (v_cantidad * v_precio_unitario * (1 - v_descuento/100) * (v_iva_percent/100));
        
        -- Actualizar stock
        UPDATE productos SET stock_actual = stock_actual - v_cantidad
        WHERE producto_id = v_producto_id;
        
        SET v_linea_index = v_linea_index + 1;
    END WHILE;
    
    -- 4. Actualizar totales del pedido
    SET v_total_pedido = v_subtotal + v_total_iva;
    
    UPDATE pedidos SET 
        subtotal = v_subtotal,
        iva = v_total_iva,
        total = v_total_pedido
    WHERE pedido_id = v_pedido_id;
    
    -- 5. Verificar límite de crédito
    IF EXISTS (
        SELECT 1 FROM clientes 
        WHERE cliente_id = v_cliente_id 
        AND limite_credito < (
            SELECT COALESCE(SUM(total), 0) 
            FROM pedidos 
            WHERE cliente_id = v_cliente_id AND estado != 'Cancelado'
        )
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente ha excedido su límite de crédito';
    END IF;
    
    -- Confirmar transacción
    COMMIT;
    
    -- Resultado exitoso
    SELECT 
        v_cliente_id AS cliente_id,
        v_pedido_id AS pedido_id,
        'Pedido creado exitosamente' AS mensaje;
END //

DELIMITER ;

-- crear informe de pedido 
DELIMITER //

CREATE PROCEDURE sp_obtener_informe_pedido(
    IN p_pedido_id INT
)
BEGIN
    -- 1. Información del cliente (para el encabezado)
    SELECT 
        c.cliente_id,
        c.codigo_cliente,
        c.nombre AS nombre_cliente,
        c.tipo AS tipo_cliente,
        c.documento_identidad,
        CONCAT(c.direccion, ', ', c.codigo_postal, ', ', c.ciudad) AS direccion_completa,
        c.telefono,
        c.email,
        c.limite_credito
    FROM 
        pedidos p
    JOIN 
        clientes c ON p.cliente_id = c.cliente_id
    WHERE 
        p.pedido_id = p_pedido_id;
    
    -- 2. Información del pedido (para el encabezado)
    SELECT 
        p.pedido_id,
        p.codigo_pedido,
        DATE_FORMAT(p.fecha_pedido, '%d/%m/%Y %H:%i') AS fecha_pedido,
        DATE_FORMAT(p.fecha_entrega_prevista, '%d/%m/%Y') AS fecha_entrega_prevista,
        p.estado,
        p.metodo_pago,
        p.direccion_entrega,
        p.notas AS notas_pedido
    FROM 
        pedidos p
    WHERE 
        p.pedido_id = p_pedido_id;
    
    -- 3. Líneas de pedido (para el cuerpo del informe)
    SELECT 
        lp.linea_id,
        pr.codigo_producto,
        pr.nombre AS producto,
        pr.descripcion,
        lp.cantidad,
        lp.precio_unitario,
        CONCAT(lp.iva_percent, '%') AS iva,
        CONCAT(lp.descuento, '%') AS descuento,
        (lp.cantidad * lp.precio_unitario * (1 - lp.descuento/100)) AS base_imponible,
        (lp.cantidad * lp.precio_unitario * (1 - lp.descuento/100) * (lp.iva_percent/100)) AS importe_iva,
        lp.total_linea
    FROM 
        lineas_pedido lp
    JOIN 
        productos pr ON lp.producto_id = pr.producto_id
    WHERE 
        lp.pedido_id = p_pedido_id
    ORDER BY 
        lp.linea_id;
    
    -- 4. Cálculo de totales (para el pie de página) - Versión corregida
    SELECT 
        COUNT(lp.linea_id) AS total_productos,
        SUM(lp.cantidad) AS total_unidades,
        SUM(lp.cantidad * lp.precio_unitario * (1 - lp.descuento/100)) AS subtotal,
        SUM(lp.cantidad * lp.precio_unitario * (1 - lp.descuento/100) * (lp.iva_percent/100)) AS iva,
        SUM(lp.total_linea) AS total,
        CASE 
            WHEN AVG(lp.iva_percent) = 21 THEN 'IVA General (21%)'
            WHEN AVG(lp.iva_percent) = 10 THEN 'IVA Reducido (10%)'
            WHEN AVG(lp.iva_percent) = 4 THEN 'IVA Superreducido (4%)'
            ELSE CONCAT('Tipo IVA Mixto (Media: ', ROUND(AVG(lp.iva_percent), 2), '%)')
        END AS tipo_iva
    FROM 
        lineas_pedido lp
    WHERE 
        lp.pedido_id = p_pedido_id;
END //

DELIMITER ;