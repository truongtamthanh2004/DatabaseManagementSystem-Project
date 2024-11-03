create database ecommerce
go
use ecommerce
go

-- 1 Bộ phận chăm sóc khách hàng
CREATE TABLE customer (
    customer_id INT PRIMARY KEY IDENTITY,
    full_name NVARCHAR(100),
    phone_number NVARCHAR(15) UNIQUE,
    birthday DATE,
    registration_date DATE DEFAULT GETDATE(),
    loyalty_level NVARCHAR(20) DEFAULT 'thân thiết', -- Default level
    last_year_spent DECIMAL(18, 2) DEFAULT 0
);

CREATE TABLE customer_transaction (
    transaction_id INT PRIMARY KEY IDENTITY,
    customer_id INT FOREIGN KEY REFERENCES customer(customer_id),
    transaction_date DATE,
    amount DECIMAL(18, 2)
);

-- 2 Bộ phận quản lý ngành hàng
CREATE TABLE category (
    category_id INT PRIMARY KEY IDENTITY,
    category_name NVARCHAR(100) NOT NULL
);

CREATE TABLE product (
    product_id INT PRIMARY KEY IDENTITY,
    category_id INT FOREIGN KEY REFERENCES category(category_id),
    product_name NVARCHAR(100) NOT NULL,
    description NVARCHAR(255),
    manufacturer NVARCHAR(100),
    list_price DECIMAL(18, 2),
    stock_quantity INT NOT NULL -- Số lượng hàng hiện có
);

CREATE TABLE promotion (
    promotion_id INT PRIMARY KEY IDENTITY,
    promotion_type NVARCHAR(20) CHECK (promotion_type IN ('flash-sale', 'combo-sale', 'member-sale')),
    discount_rate DECIMAL(5, 2) NOT NULL, -- Phần trăm giảm giá
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    max_quantity INT NOT NULL -- Số lượng tối đa sản phẩm được áp dụng
);

CREATE TABLE promotion_product (
    promotion_id INT FOREIGN KEY REFERENCES promotion(promotion_id),
    product_id INT FOREIGN KEY REFERENCES product(product_id),
    current_quantity INT CHECK (current_quantity >= 0) -- Số lượng khuyến mãi còn lại
);

CREATE TABLE loyalty_level_discount (
    level_name NVARCHAR(20) PRIMARY KEY,
    discount_rate DECIMAL(5, 2) -- Phần trăm giảm giá
);

ALTER TABLE customer
ADD CONSTRAINT fk_loyalty_level
FOREIGN KEY (loyalty_level) REFERENCES loyalty_level_discount(level_name);




