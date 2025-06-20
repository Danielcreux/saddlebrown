-- Vista Detallada de Líneas de Pedido
CREATE VIEW vista_detalle_lineas_pedido AS
SELECT 
    lp.linea_id,
    p.pedido_id,
    p.codigo_pedido,
    DATE_FORMAT(p.fecha_pedido, '%d/%m/%Y %H:%i') AS fecha_pedido,
    p.estado AS estado_pedido,
    c.cliente_id,
    c.nombre AS nombre_cliente,
    c.tipo AS tipo_cliente,
    pr.producto_id,
    pr.codigo_producto,
    pr.nombre AS nombre_producto,
    pr.categoria_id,
    CASE 
        WHEN pr.categoria_id = 1 THEN 'Perfume de Nicho'
        WHEN pr.categoria_id = 2 THEN 'Perfume de Diseñador'
        ELSE 'Otra categoría'
    END AS categoria_producto,
    lp.cantidad,
    lp.precio_unitario,
    lp.iva_percent AS iva,
    lp.descuento,
    lp.total_linea,
    p.total AS total_pedido,
    p.fecha_entrega_prevista,
    DATEDIFF(p.fecha_entrega_prevista, CURDATE()) AS dias_para_entrega,
    lp.notas AS notas_linea,
    p.notas AS notas_pedido
FROM 
    lineas_pedido lp
JOIN 
    pedidos p ON lp.pedido_id = p.pedido_id
JOIN 

-- Vista Resumen de Pedidos por Cliente

CREATE VIEW vista_resumen_pedidos_clientes AS
SELECT 
    c.cliente_id,
    c.codigo_cliente,
    c.nombre AS nombre_cliente,
    c.tipo AS tipo_cliente,
    c.ciudad,
    COUNT(DISTINCT p.pedido_id) AS total_pedidos,
    SUM(lp.total_linea) AS importe_total,
    MAX(p.fecha_pedido) AS ultimo_pedido,
    AVG(lp.total_linea) AS ticket_medio,
    c.limite_credito,
    (c.limite_credito - SUM(lp.total_linea)) AS credito_disponible
FROM 
    clientes c
JOIN 
    pedidos p ON c.cliente_id = p.cliente_id
JOIN 
    lineas_pedido lp ON p.pedido_id = lp.pedido_id
WHERE 
    p.estado NOT IN ('Cancelado')
GROUP BY 
    c.cliente_id, c.codigo_cliente, c.nombre, c.tipo, c.ciudad, c.limite_credito;
    clientes c ON p.cliente_id = c.cliente_id
JOIN 
    productos pr ON lp.producto_id = pr.producto_id;
    
-- Vista de Productos Más Vendidos

CREATE VIEW vista_productos_mas_vendidos AS
SELECT 
    pr.producto_id,
    pr.codigo_producto,
    pr.nombre AS nombre_producto,
    pr.categoria_id,
    CASE 
        WHEN pr.categoria_id = 1 THEN 'Nicho'
        WHEN pr.categoria_id = 2 THEN 'Designer'
        ELSE 'Otra categoría'
    END AS categoria,
    COUNT(lp.linea_id) AS veces_vendido,
    SUM(lp.cantidad) AS unidades_vendidas,
    SUM(lp.total_linea) AS ingresos_generados,
    pr.precio_venta,
    pr.stock_actual,
    CASE 
        WHEN pr.stock_actual < pr.stock_minimo THEN 'REPONER'
        ELSE 'OK'
    END AS estado_stock
FROM 
    productos pr
JOIN 
    lineas_pedido lp ON pr.producto_id = lp.producto_id
JOIN 
    pedidos p ON lp.pedido_id = p.pedido_id
WHERE 
    p.estado NOT IN ('Cancelado')
GROUP BY 
    pr.producto_id, pr.codigo_producto, pr.nombre, pr.categoria_id, pr.precio_venta, pr.stock_actual, pr.stock_minimo
ORDER BY 
    ingresos_generados DESC;
    
-- Vista de Pedidos Pendientes
CREATE VIEW vista_pedidos_pendientes AS
SELECT 
    p.pedido_id,
    p.codigo_pedido,
    c.cliente_id,
    c.nombre AS nombre_cliente,
    c.telefono,
    c.email,
    DATE_FORMAT(p.fecha_pedido, '%d/%m/%Y') AS fecha_pedido,
    DATE_FORMAT(p.fecha_entrega_prevista, '%d/%m/%Y') AS fecha_entrega,
    p.estado,
    COUNT(lp.linea_id) AS total_lineas,
    SUM(lp.cantidad) AS total_productos,
    p.total AS importe_total,
    p.metodo_pago,
    p.notas
FROM 
    pedidos p
JOIN 
    clientes c ON p.cliente_id = c.cliente_id
JOIN 
    lineas_pedido lp ON p.pedido_id = lp.pedido_id
WHERE 
    p.estado IN ('Pendiente', 'Procesando')
GROUP BY 
    p.pedido_id, p.codigo_pedido, c.cliente_id, c.nombre, c.telefono, c.email, 
    p.fecha_pedido, p.fecha_entrega_prevista, p.estado, p.total, p.metodo_pago, p.notas
ORDER BY 
    p.fecha_entrega_prevista ASC;
    
-- Vista de Ventas por Categoría y Mes    
CREATE VIEW vista_ventas_por_categoria_mes AS
SELECT 
    CASE 
        WHEN pr.categoria_id = 1 THEN 'Nicho'
        WHEN pr.categoria_id = 2 THEN 'Designer'
        ELSE 'Otra categoría'
    END AS categoria,
    DATE_FORMAT(p.fecha_pedido, '%Y-%m') AS mes,
    COUNT(DISTINCT p.pedido_id) AS total_pedidos,
    SUM(lp.cantidad) AS unidades_vendidas,
    SUM(lp.total_linea) AS ingresos,
    AVG(lp.total_linea) AS ticket_medio
FROM 
    productos pr
JOIN 
    lineas_pedido lp ON pr.producto_id = lp.producto_id
JOIN 
    pedidos p ON lp.pedido_id = p.pedido_id
WHERE 
    p.estado NOT IN ('Cancelado')
GROUP BY 
    categoria, mes
ORDER BY 
    mes DESC, ingresos DESC;
    

-- Consultar la vista detallada
SELECT * FROM vista_detalle_lineas_pedido WHERE estado_pedido = 'Pendiente';

-- Consultar productos más vendidos de nicho
SELECT * FROM vista_productos_mas_vendidos WHERE categoria = 'Nicho';

-- Obtener resumen de un cliente específico
SELECT * FROM vista_resumen_pedidos_clientes WHERE cliente_id = 5;


DELIMITER //

-- Procedimiento Almacenado Equivalente a la Vista

CREATE PROCEDURE sp_obtener_lineas_pedido_completo(IN p_pedido_id INT)
BEGIN
    -- Verificar si el pedido existe
    IF NOT EXISTS (SELECT 1 FROM pedidos WHERE pedido_id = p_pedido_id) THEN
        SELECT 'Error: El pedido especificado no existe' AS Mensaje;
    ELSE
        -- Consulta idéntica a la vista pero filtrada por pedido_id
        SELECT 
            lp.linea_id,
            p.pedido_id,
            p.codigo_pedido,
            DATE_FORMAT(p.fecha_pedido, '%d/%m/%Y %H:%i') AS fecha_pedido,
            p.estado AS estado_pedido,
            c.cliente_id,
            c.nombre AS nombre_cliente,
            c.tipo AS tipo_cliente,
            pr.producto_id,
            pr.codigo_producto,
            pr.nombre AS nombre_producto,
            pr.categoria_id,
            CASE 
                WHEN pr.categoria_id = 1 THEN 'Perfume de Nicho'
                WHEN pr.categoria_id = 2 THEN 'Perfume de Diseñador'
                ELSE 'Otra categoría'
            END AS categoria_producto,
            lp.cantidad,
            lp.precio_unitario,
            lp.iva_percent AS iva,
            lp.descuento,
            lp.total_linea,
            p.total AS total_pedido,
            p.fecha_entrega_prevista,
            DATEDIFF(p.fecha_entrega_prevista, CURDATE()) AS dias_para_entrega,
            lp.notas AS notas_linea,
            p.notas AS notas_pedido
        FROM 
            lineas_pedido lp
        JOIN 
            pedidos p ON lp.pedido_id = p.pedido_id
        JOIN 
            clientes c ON p.cliente_id = c.cliente_id
        JOIN 
            productos pr ON lp.producto_id = pr.producto_id
        WHERE 
            p.pedido_id = p_pedido_id
        ORDER BY 
            lp.linea_id;
    END IF;
END //

DELIMITER ;


-- Procedimiento para el login 
DELIMITER //

CREATE PROCEDURE sp_check_login(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    OUT p_is_valid BOOLEAN)
BEGIN
    DECLARE stored_hash VARCHAR(255);
    
    -- Obtener el hash almacenado
    SELECT password_hash INTO stored_hash
    FROM users 
    WHERE username = p_username AND is_active = TRUE
    LIMIT 1;
    
    -- Comparación SIMULADA (esto NO es seguro para producción)
    -- Solo funciona si la contraseña es igual al nombre de usuario
    SET p_is_valid = (stored_hash IS NOT NULL AND p_password = p_username);
END //

DELIMITER ;