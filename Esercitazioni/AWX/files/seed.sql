DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL,
    city VARCHAR(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO customers (full_name, email, city) VALUES ('Mario Rossi',    'mario.rossi@example.test',    'Bologna');
INSERT INTO customers (full_name, email, city) VALUES ('Luigi Bianchi',  'luigi.bianchi@example.test',  'Milano');
INSERT INTO customers (full_name, email, city) VALUES ('Anna Verdi',     'anna.verdi@example.test',     'Roma');
INSERT INTO customers (full_name, email, city) VALUES ('Sara Neri',      'sara.neri@example.test',      'Torino');
INSERT INTO customers (full_name, email, city) VALUES ('Paolo Gialli',   'paolo.gialli@example.test',   'Napoli');

CREATE TABLE orders (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_id INT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL,
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO orders (customer_id, amount, status) VALUES (1, 49.90,  'delivered');
INSERT INTO orders (customer_id, amount, status) VALUES (1, 15.00,  'shipped');
INSERT INTO orders (customer_id, amount, status) VALUES (2, 120.50, 'pending');
INSERT INTO orders (customer_id, amount, status) VALUES (3, 8.75,   'delivered');
INSERT INTO orders (customer_id, amount, status) VALUES (5, 300.00, 'shipped');