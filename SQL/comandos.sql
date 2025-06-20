-- 1. Crear la base de datos saddlebrown con codificación UTF8MB4
CREATE DATABASE IF NOT EXISTS saddlebrown 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 2. Crear el usuario saddlebrown con contraseña saddlebrown
CREATE USER IF NOT EXISTS 'saddlebrown'@'localhost' IDENTIFIED BY 'saddlebrown';

-- 3. Otorgar todos los privilegios sobre la base de datos saddlebrown al usuario
GRANT ALL PRIVILEGES ON saddlebrown.* TO 'saddlebrown'@'localhost';

-- 4. Aplicar los cambios de privilegios
FLUSH PRIVILEGES;

-- 5. Usar la base de datos saddlebrown
USE saddlebrown;

-- Crear usuario

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    fullname VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Store hashed passwords, never plain text
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME NULL,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_username (username),
    INDEX idx_email (email),
    CONSTRAINT chk_email_format CHECK (email LIKE '%@%.%')
) ENGINE=InnoDB;

-- 2. Tabla de Clientes (solución alternativa)
CREATE TABLE clientes (
    cliente_id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_cliente VARCHAR(20) NOT NULL DEFAULT '',
    nombre VARCHAR(100) NOT NULL,
    tipo ENUM('Persona', 'Empresa') NOT NULL,
    documento_identidad VARCHAR(20) UNIQUE,
    direccion TEXT,
    ciudad VARCHAR(50),
    pais VARCHAR(50) DEFAULT 'España',
    codigo_postal VARCHAR(10),
    telefono VARCHAR(20),
    email VARCHAR(100),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    limite_credito DECIMAL(10,2) DEFAULT 0.00,
    INDEX idx_nombre (nombre),
    INDEX idx_email (email),
    INDEX idx_activo (activo),
    CONSTRAINT chk_email CHECK (email LIKE '%@%.%'),
    CONSTRAINT chk_limite_credito CHECK (limite_credito >= 0)
) ENGINE=InnoDB;

-- 3. Tabla de Productos (solución alternativa)
CREATE TABLE productos (
    producto_id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_producto VARCHAR(20) NOT NULL DEFAULT '',
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    categoria_id INT,
    precio_venta DECIMAL(10,2) NOT NULL,
    precio_compra DECIMAL(10,2),
    iva_percent DECIMAL(5,2) DEFAULT 21.00,
    stock_actual DECIMAL(10,2) DEFAULT 0.00,
    stock_minimo DECIMAL(10,2) DEFAULT 5.00,
    unidad_medida VARCHAR(10) DEFAULT 'UN',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    imagen VARCHAR(255),
    INDEX idx_nombre (nombre),
    INDEX idx_codigo (codigo_producto),
    INDEX idx_categoria (categoria_id),
    INDEX idx_activo (activo),
    CONSTRAINT chk_precio_venta CHECK (precio_venta > 0),
    CONSTRAINT chk_stock CHECK (stock_actual >= 0)
) ENGINE=InnoDB;

-- 4. Tabla de Pedidos (solución alternativa)
CREATE TABLE pedidos (
    pedido_id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_pedido VARCHAR(20) NOT NULL DEFAULT '',
    cliente_id INT NOT NULL,
    fecha_pedido DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega_prevista DATE,
    estado ENUM('Pendiente', 'Procesando', 'Enviado', 'Entregado', 'Cancelado') DEFAULT 'Pendiente',
    subtotal DECIMAL(12,2) DEFAULT 0.00,
    iva DECIMAL(12,2) DEFAULT 0.00,
    total DECIMAL(12,2) DEFAULT 0.00,
    metodo_pago ENUM('Efectivo', 'Tarjeta', 'Transferencia', 'Bizum') DEFAULT 'Transferencia',
    notas TEXT,
    direccion_entrega TEXT,
    INDEX idx_cliente (cliente_id),
    INDEX idx_fecha (fecha_pedido),
    INDEX idx_estado (estado),
    INDEX idx_codigo (codigo_pedido),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) 
        REFERENCES clientes(cliente_id) 
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5. Tabla de Líneas de Pedido
CREATE TABLE lineas_pedido (
    linea_id INT AUTO_INCREMENT PRIMARY KEY,
    pedido_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    iva_percent DECIMAL(5,2) NOT NULL,
    descuento DECIMAL(5,2) DEFAULT 0.00,
    total_linea DECIMAL(12,2) AS (ROUND(cantidad * precio_unitario * (1 - descuento/100) * (1 + iva_percent/100), 2)),
    notas TEXT,
    INDEX idx_pedido (pedido_id),
    INDEX idx_producto (producto_id),
    CONSTRAINT fk_linea_pedido FOREIGN KEY (pedido_id) 
        REFERENCES pedidos(pedido_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_linea_producto FOREIGN KEY (producto_id) 
        REFERENCES productos(producto_id),
    CONSTRAINT chk_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_precio_unitario CHECK (precio_unitario > 0)
) ENGINE=InnoDB;

-- 6. Triggers para generar los códigos automáticos
DELIMITER //
CREATE TRIGGER before_clientes_insert
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    DECLARE next_id INT;
    
    -- Obtener el próximo ID (esto funciona porque el trigger se ejecuta antes de la inserción)
    SELECT COALESCE(MAX(cliente_id), 0) + 1 INTO next_id FROM clientes;
    
    -- Generar el código de cliente
    SET NEW.codigo_cliente = CONCAT('CLI-', LPAD(next_id, 5, '0'));
END//

CREATE TRIGGER before_productos_insert
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    DECLARE next_id INT;
    
    -- Obtener el próximo ID
    SELECT COALESCE(MAX(producto_id), 0) + 1 INTO next_id FROM productos;
    
    -- Generar el código de producto
    SET NEW.codigo_producto = CONCAT('PROD-', LPAD(next_id, 5, '0'));
END//

CREATE TRIGGER before_pedidos_insert
BEFORE INSERT ON pedidos
FOR EACH ROW
BEGIN
    DECLARE next_id INT;
    
    -- Obtener el próximo ID
    SELECT COALESCE(MAX(pedido_id), 0) + 1 INTO next_id FROM pedidos;
    
    -- Generar el código de pedido (usando la fecha actual)
    SET NEW.codigo_pedido = CONCAT('PED-', DATE_FORMAT(NOW(), '%Y%m-'), LPAD(next_id, 5, '0'));
END//
DELIMITER ;

-- Password will be stored as hash (for 'danielcreux' using bcrypt)
INSERT INTO users (fullname, email, username, password_hash) 
VALUES (
);

-- Clientes particulares
INSERT INTO clientes (codigo_cliente, nombre, tipo, documento_identidad, direccion, ciudad, codigo_postal, telefono, email, limite_credito) VALUES
('CLI-1001', 'María González Pérez', 'Persona', '12345678A', 'Calle Gran Vía 45, 3ºB', 'Madrid', '28013', '+34611223344', 'maria.gonzalez@email.com', 5000.00),
('CLI-1002', 'Carlos Ruiz Sánchez', 'Persona', '87654321B', 'Avenida Diagonal 123, 1º2ª', 'Barcelona', '08008', '+34655443322', 'carlos.ruiz@email.com', 3000.00),
('CLI-1003', 'Ana Martínez López', 'Persona', '11223344C', 'Plaza Mayor 7, 4ºD', 'Valencia', '46002', '+34677665544', 'ana.martinez@email.com', 2000.00),
('CLI-1004', 'David Fernández García', 'Persona', '44332211D', 'Calle Sierpes 25', 'Sevilla', '41004', '+34699887766', 'david.fernandez@email.com', 1500.00),
('CLI-1005', 'Laura Gómez Rodríguez', 'Persona', '55667788E', 'Calle Alfonso X 12', 'Bilbao', '48010', '+34611223355', 'laura.gomez@email.com', 2500.00);

-- Clientes empresas (perfumerías y tiendas especializadas)
INSERT INTO clientes (codigo_cliente, nombre, tipo, documento_identidad, direccion, ciudad, codigo_postal, telefono, email, limite_credito) VALUES
('CLI-2001', 'Perfumería Elegance S.L.', 'Empresa', 'A12345678', 'Paseo de Gracia 56', 'Barcelona', '08007', '+34931234567', 'info@elegance-perfumes.com', 15000.00),
('CLI-2002', 'The Scent Room Boutique', 'Empresa', 'B87654321', 'Calle Serrano 89', 'Madrid', '28006', '+34914567890', 'contact@thescentroom.com', 20000.00),
('CLI-2003', 'Aromas Selectos S.A.', 'Empresa', 'C11223344', 'Avenida de la Constitución 34', 'Sevilla', '41001', '+34954567890', 'ventas@aromaselectos.com', 10000.00),
('CLI-2004', 'Niche Perfumes Valencia', 'Empresa', 'D44332211', 'Calle Colón 67', 'Valencia', '46004', '+34963456789', 'info@nicheperfumesvalencia.com', 8000.00),
('CLI-2005', 'Luxury Scents Bilbao', 'Empresa', 'E55667788', 'Gran Vía 23', 'Bilbao', '48001', '+34944556677', 'sales@luxuryscentsbilbao.com', 12000.00);

-- Perfumes de nicho
INSERT INTO productos (codigo_producto, nombre, descripcion, precio_venta, precio_compra, iva_percent, stock_actual, stock_minimo, imagen) VALUES
('PERF-1001', 'Creed Aventus', 'Fragancia icónica con notas de piña, abedul y musk. Edición limitada.', 350.00, 220.00, 21.00, 15, 3, 'creed_aventus.jpg'),
('PERF-1002', 'Le Labo Santal 33', 'Perfume unisex con notas de sándalo, cardamomo y violeta. Artesanal.', 280.00, 180.00, 21.00, 22, 5, 'lelabo_santal33.jpg'),
('PERF-1003', 'Byredo Gypsy Water', 'Fragancia nómada con notas de limón, pino y vainilla.', 240.00, 150.00, 21.00, 18, 4, 'byredo_gypsywater.jpg'),
('PERF-1004', 'Maison Francis Kurkdjian Baccarat Rouge 540', 'Fragancia de lujo con notas de azafrán, almizcle y madera de cedro.', 420.00, 280.00, 21.00, 8, 2, 'mfk_baccarat.jpg'),
('PERF-1005', 'Tom Ford Tobacco Vanille', 'Perfume cálido con notas de tabaco, vainilla y frutas secas.', 320.00, 210.00, 21.00, 12, 3, 'tomford_tobacco.jpg'),
('PERF-1006', 'Serge Lutens Ambre Sultan', 'Fragancia oriental con notas de ámbar, resinas y especias.', 290.00, 190.00, 21.00, 10, 2, 'lutens_ambre.jpg'),
('PERF-1007', 'Diptyque Philosykos', 'Perfume fresco con notas de higo, hojas verdes y madera.', 230.00, 145.00, 21.00, 20, 5, 'diptyque_philosykos.jpg'),
('PERF-1008', 'Xerjoff Naxos', 'Fragancia sofisticada con notas de lavanda, miel y tabaco.', 380.00, 250.00, 21.00, 7, 2, 'xerjoff_naxos.jpg'),
('PERF-1009', 'Nasomatto Black Afgano', 'Perfume intenso con notas de sándalo, cannabis y especias.', 340.00, 220.00, 21.00, 5, 1, 'nasomatto_black.jpg'),
('PERF-1010', 'Roja Parfums Enigma', 'Fragancia exclusiva con notas de coñac, especias y ámbar.', 450.00, 300.00, 21.00, 3, 1, 'roja_enigma.jpg');

-- Perfumes de marcas reconocidas
INSERT INTO productos (codigo_producto, nombre, descripcion, precio_venta, precio_compra, iva_percent, stock_actual, stock_minimo, imagen) VALUES
('PERF-2001', 'Chanel N°5', 'Clásico floral aldehídico con notas de jazmín y rosa.', 120.00, 75.00, 21.00, 35, 10, 'chanel_no5.jpg'),
('PERF-2002', 'Dior Sauvage', 'Fragancia fresca y especiada con notas de pimienta y lavanda.', 95.00, 60.00, 21.00, 50, 15, 'dior_sauvage.jpg'),
('PERF-2003', 'Guerlain Shalimar', 'Perfume oriental legendario con notas de vainilla y bergamota.', 110.00, 70.00, 21.00, 25, 8, 'guerlain_shalimar.jpg'),
('PERF-2004', 'Yves Saint Laurent Black Opium', 'Fragancia adictiva con notas de café y vainilla.', 105.00, 65.00, 21.00, 40, 12, 'ysl_blackopium.jpg'),
('PERF-2005', 'Jo Malone Wood Sage & Sea Salt', 'Perfume fresco con notas marinas y de madera.', 115.00, 75.00, 21.00, 30, 10, 'jomalone_woodsage.jpg'),
('PERF-2006', 'Hermès Terre d\'Hermès', 'Fragancia terrenal con notas de cítricos y vetiver.', 100.00, 65.00, 21.00, 28, 8, 'hermes_terre.jpg'),
('PERF-2007', 'Paco Rabanne 1 Million', 'Perfume intenso con notas de canela y cuero.', 85.00, 55.00, 21.00, 45, 15, 'paco_1million.jpg'),
('PERF-2008', 'Calvin Klein Euphoria', 'Fragancia sensual con notas de granada y orquídea.', 75.00, 50.00, 21.00, 38, 12, 'ck_euphoria.jpg'),
('PERF-2009', 'Armani Acqua di Giò', 'Perfume acuático con notas marinas y cítricos.', 90.00, 60.00, 21.00, 42, 15, 'armani_acqua.jpg'),
('PERF-2010', 'Versace Eros', 'Fragancia vibrante con notas de menta y vainilla.', 80.00, 50.00, 21.00, 36, 12, 'versace_eros.jpg');

-- Pedidos de clientes
INSERT INTO pedidos (codigo_pedido, cliente_id, fecha_pedido, fecha_entrega_prevista, estado, subtotal, iva, total, metodo_pago, notas) VALUES
('PED-1001', 1, '2023-05-10 14:30:00', '2023-05-15', 'Entregado', 670.00, 140.70, 810.70, 'Tarjeta', 'Regalo de cumpleaños - Enviar con tarjeta'),
('PED-1002', 6, '2023-05-12 11:15:00', '2023-05-18', 'Enviado', 1450.00, 304.50, 1754.50, 'Transferencia', 'Pedido para tienda - Factura a nombre de Perfumería Elegance S.L.'),
('PED-1003', 3, '2023-05-15 16:45:00', '2023-05-20', 'Procesando', 380.00, 79.80, 459.80, 'Bizum', 'Cliente preferente - Descuento especial aplicado manualmente'),
('PED-1004', 8, '2023-05-18 09:30:00', '2023-05-25', 'Pendiente', 2200.00, 462.00, 2662.00, 'Transferencia', 'Pedido mayorista - Verificar stock antes de enviar'),
('PED-1005', 2, '2023-05-20 13:20:00', '2023-05-25', 'Entregado', 540.00, 113.40, 653.40, 'Tarjeta', 'Enviar a dirección de trabajo'),
('PED-1006', 7, '2023-05-22 10:00:00', '2023-05-29', 'Enviado', 980.00, 205.80, 1185.80, 'Transferencia', 'Factura con IVA incluido - Urgente'),
('PED-1007', 4, '2023-05-25 17:30:00', '2023-06-01', 'Procesando', 720.00, 151.20, 871.20, 'Tarjeta', 'Cliente nuevo - Enviar muestras'),
('PED-1008', 9, '2023-05-28 12:45:00', '2023-06-05', 'Pendiente', 1600.00, 336.00, 1936.00, 'Transferencia', 'Pedido para evento especial'),
('PED-1009', 5, '2023-05-30 15:10:00', '2023-06-06', 'Entregado', 420.00, 88.20, 508.20, 'Bizum', 'Enviar a dirección alternativa'),
('PED-1010', 10, '2023-06-01 11:30:00', '2023-06-08', 'Enviado', 3100.00, 651.00, 3751.00, 'Transferencia', 'Pedido mayorista - Verificar todos los productos');

-- Líneas de pedido para los pedidos anteriores
INSERT INTO lineas_pedido (pedido_id, producto_id, cantidad, precio_unitario, iva_percent, descuento, notas) VALUES
-- Pedido 1
(1, 1, 1, 350.00, 21.00, 0.00, 'Edición limitada'),
(1, 11, 1, 120.00, 21.00, 0.00, 'Presentación estándar'),
(1, 15, 2, 100.00, 21.00, 0.00, 'Regalo'),

-- Pedido 2
(2, 3, 3, 240.00, 21.00, 5.00, 'Para tienda'),
(2, 6, 2, 290.00, 21.00, 5.00, 'Para tienda'),
(2, 12, 1, 95.00, 21.00, 0.00, 'Exhibición'),

-- Pedido 3
(3, 4, 1, 420.00, 21.00, 10.00, 'Cliente VIP'),

-- Pedido 4
(4, 5, 4, 320.00, 21.00, 15.00, 'Mayorista'),
(4, 10, 2, 450.00, 21.00, 15.00, 'Mayorista'),

-- Pedido 5
(5, 2, 1, 280.00, 21.00, 0.00, 'Sin notas'),
(5, 14, 1, 105.00, 21.00, 0.00, 'Sin notas'),
(5, 20, 1, 80.00, 21.00, 0.00, 'Sin notas'),

-- Pedido 6
(6, 7, 2, 230.00, 21.00, 0.00, 'Urgente'),
(6, 8, 1, 380.00, 21.00, 0.00, 'Urgente'),
(6, 13, 1, 110.00, 21.00, 0.00, 'Urgente'),

-- Pedido 7
(7, 9, 1, 340.00, 21.00, 0.00, 'Muestras incluidas'),
(7, 16, 1, 100.00, 21.00, 0.00, 'Muestras incluidas'),
(7, 18, 1, 75.00, 21.00, 0.00, 'Muestras incluidas'),
(7, 19, 1, 90.00, 21.00, 0.00, 'Muestras incluidas'),

-- Pedido 8
(8, 1, 2, 350.00, 21.00, 10.00, 'Evento corporativo'),
(8, 4, 1, 420.00, 21.00, 10.00, 'Evento corporativo'),
(8, 10, 1, 450.00, 21.00, 10.00, 'Evento corporativo'),

-- Pedido 9
(9, 3, 1, 240.00, 21.00, 0.00, 'Envolver para regalo'),
(9, 17, 1, 85.00, 21.00, 0.00, 'Envolver para regalo'),

-- Pedido 10
(10, 2, 5, 280.00, 21.00, 20.00, 'Pedido mayorista'),
(10, 5, 3, 320.00, 21.00, 20.00, 'Pedido mayorista'),
(10, 11, 4, 120.00, 21.00, 20.00, 'Pedido mayorista'),
(10, 20, 6, 80.00, 21.00, 20.00, 'Pedido mayorista');
                     