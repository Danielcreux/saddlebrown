-- toda la información relacionada con cada línea de pedido, incluyendo datos del cliente, pedido, producto y la línea
SELECT 
    c.cliente_id,
    c.nombre AS nombre_cliente,
    c.tipo AS tipo_cliente,
    c.email AS email_cliente,
    p.codigo_pedido,
    p.fecha_pedido,
    p.fecha_entrega_prevista,
    p.estado AS estado_pedido,
    p.total AS total_pedido,
    pr.codigo_producto,
    pr.nombre AS nombre_producto,
    pr.descripcion AS descripcion_producto,
    pr.precio_venta AS precio_unitario_producto,
    lp.linea_id,
    lp.cantidad,
    lp.precio_unitario AS precio_unitario_linea,
    lp.iva_percent AS iva_linea,
    lp.descuento AS descuento_linea,
    lp.total_linea,
    lp.notas AS notas_linea
FROM 
    lineas_pedido lp
JOIN 
    pedidos p ON lp.pedido_id = p.pedido_id
JOIN 
    clientes c ON p.cliente_id = c.cliente_id
JOIN 
    productos pr ON lp.producto_id = pr.producto_id
ORDER BY 
    p.fecha_pedido DESC, lp.linea_id;
    
-- Version con mas detalles
SELECT 
    p.codigo_pedido,
    DATE_FORMAT(p.fecha_pedido, '%d/%m/%Y %H:%i') AS fecha_pedido_formateada,
    CONCAT(c.nombre, ' (', c.tipo, ')') AS cliente,
    c.email AS contacto,
    pr.codigo_producto,
    pr.nombre AS producto,
    CONCAT('€', FORMAT(lp.precio_unitario, 2)) AS precio_unitario,
    lp.cantidad,
    CONCAT(lp.descuento, '%') AS descuento,
    CONCAT('€', FORMAT(lp.total_linea, 2)) AS total_linea,
    p.estado AS estado_pedido,
    CONCAT('€', FORMAT(p.total, 2)) AS total_pedido,
    CASE 
        WHEN DATEDIFF(p.fecha_entrega_prevista, CURDATE()) > 0 
        THEN CONCAT('En ', DATEDIFF(p.fecha_entrega_prevista, CURDATE()), ' días')
        WHEN DATEDIFF(p.fecha_entrega_prevista, CURDATE()) = 0 
        THEN 'Hoy'
        ELSE CONCAT('Hace ', ABS(DATEDIFF(p.fecha_entrega_prevista, CURDATE())), ' días')
    END AS entrega,
    lp.notas AS observaciones
FROM 
    lineas_pedido lp
JOIN 
    pedidos p ON lp.pedido_id = p.pedido_id
JOIN 
    clientes c ON p.cliente_id = c.cliente_id
JOIN 
    productos pr ON lp.producto_id = pr.producto_id
WHERE 
    p.estado NOT IN ('Cancelado')
ORDER BY 
    p.fecha_pedido DESC, lp.linea_id;
    
-- Consulta especifica para perfumes de nicho 

SELECT 
    p.codigo_pedido,
    c.nombre AS cliente,
    pr.nombre AS producto,
    pr.categoria_id,
    CASE 
        WHEN pr.categoria_id = 1 THEN 'Nicho'
        WHEN pr.categoria_id = 2 THEN 'Designer'
        ELSE 'Otra categoría'
    END AS tipo_perfume,
    lp.cantidad,
    lp.precio_unitario,
    lp.total_linea,
    DATE_FORMAT(p.fecha_pedido, '%Y-%m-%d') AS fecha
FROM 
    lineas_pedido lp
JOIN 
    pedidos p ON lp.pedido_id = p.pedido_id
JOIN 
    clientes c ON p.cliente_id = c.cliente_id
JOIN 
    productos pr ON lp.producto_id = pr.producto_id
WHERE 
    pr.categoria_id = 1  -- Solo perfumes de nicho
ORDER BY 
    p.fecha_pedido DESC;
    
-- Consulta con GROUP BY para resumen por cliente

SELECT 
    c.cliente_id,
    c.nombre AS cliente,
    COUNT(DISTINCT p.pedido_id) AS total_pedidos,
    COUNT(lp.linea_id) AS total_lineas,
    SUM(lp.total_linea) AS importe_total,
    MAX(p.fecha_pedido) AS ultimo_pedido
FROM 
    clientes c
JOIN 
    pedidos p ON c.cliente_id = p.cliente_id
JOIN 
    lineas_pedido lp ON p.pedido_id = lp.pedido_id
GROUP BY 
    c.cliente_id, c.nombre
ORDER BY 
    importe_total DESC;