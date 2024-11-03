use ecommerce;
go

-- 1
CREATE PROCEDURE update_customer_loyalty_levels
AS
BEGIN
    DECLARE @current_date DATE = GETDATE();

    -- Calculate the spending of each customer for the last 12 months
    UPDATE customer
    SET last_year_spent = (
        SELECT ISNULL(SUM(t.amount), 0)
        FROM customer_transaction t
        WHERE t.customer_id = customer.customer_id 
            AND t.transaction_date BETWEEN DATEADD(YEAR, -1, @current_date) AND @current_date
    );

    -- Update loyalty levels based on last_year_spent
    UPDATE customer
    SET loyalty_level = CASE
        WHEN last_year_spent >= 50000000 THEN 'kim cương'
        WHEN last_year_spent >= 30000000 THEN 'bạch kim'
        WHEN last_year_spent >= 15000000 THEN 'vàng'
        WHEN last_year_spent >= 5000000 THEN 'bạc'
        WHEN last_year_spent >= 2500000 THEN 'đồng'
        ELSE 'thân thiết'
    END;
END;

go

CREATE PROCEDURE send_birthday_vouchers
AS
BEGIN
    DECLARE @current_month INT = MONTH(GETDATE());

    -- Send vouchers to customers with birthdays this month
    SELECT 
        customer_id,
        full_name,
        phone_number,
        loyalty_level,
        CASE 
            WHEN loyalty_level = 'kim cương' THEN 1200000
            WHEN loyalty_level = 'bạch kim' THEN 700000
            WHEN loyalty_level = 'vàng' THEN 500000
            WHEN loyalty_level = 'bạc' THEN 200000
            WHEN loyalty_level = 'đồng' THEN 100000
            ELSE 0
        END AS voucher_amount
    FROM customer
    WHERE MONTH(birthday) = @current_month
        AND loyalty_level <> 'thân thiết';
END;
go

-- 2
CREATE PROCEDURE CheckExpiredPromotions
AS
BEGIN
    -- Delete promotions that are expired, out of stock, or have reached the maximum quantity
    DELETE FROM promotion_product
    WHERE 
        current_quantity = 0
        OR EXISTS (
            SELECT 1
            FROM promotion p
            WHERE p.promotion_id = promotion_product.promotion_id
              AND (
                    p.end_date < GETDATE() -- Promotion has expired
                    OR promotion_product.quantity_sold >= p.max_quantity -- Promotion has reached maximum quantity
                  )
        );
END;
GO

go

CREATE PROCEDURE ProcessPurchase
    @customer_id INT,
    @product_id INT,
    @quantity INT,
    @loyalty_level NVARCHAR(20) = NULL -- Optional parameter for member-sale promotions
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @stock_quantity INT;
    DECLARE @selected_promotion_id INT;
    DECLARE @selected_discount_rate DECIMAL(5, 2);
    DECLARE @promotion_type NVARCHAR(20);
    DECLARE @final_discount_rate DECIMAL(5, 2);
    DECLARE @required_stock INT;

    -- 1. Check product stock
    SELECT @stock_quantity = stock_quantity
    FROM product
    WHERE product_id = @product_id;

    -- 2. Get the highest-priority promotion for the product based on promotion type
    SELECT TOP 1 
        @selected_promotion_id = pp.promotion_id,
        @selected_discount_rate = p.discount_rate,
        @promotion_type = p.promotion_type
    FROM 
        promotion_product pp
    JOIN 
        promotion p ON pp.promotion_id = p.promotion_id
    WHERE 
        pp.product_id = @product_id
        AND pp.current_quantity > 0
        AND GETDATE() BETWEEN p.start_date AND p.end_date
    ORDER BY 
        CASE 
            WHEN p.promotion_type = 'flash-sale' THEN 1
            WHEN p.promotion_type = 'combo-sale' THEN 2
            WHEN p.promotion_type = 'member-sale' THEN 3
        END;

    -- 3. Check if the customer qualifies for a loyalty level discount (only for member-sale promotions)
    IF @promotion_type = 'member-sale' AND @loyalty_level IS NOT NULL
    BEGIN
        DECLARE @loyalty_discount_rate DECIMAL(5, 2);

        SELECT @loyalty_discount_rate = discount_rate
        FROM loyalty_level_discount
        WHERE level_name = @loyalty_level
          AND promotion_id = @selected_promotion_id;

        -- Calculate the final discount rate for member-sale (loyalty level + promotion discount)
        SET @final_discount_rate = COALESCE(@loyalty_discount_rate, 0) + @selected_discount_rate;
    END
    ELSE
    BEGIN
        -- For flash-sale and combo-sale, use only the selected promotion discount rate
        SET @final_discount_rate = @selected_discount_rate;
    END

    -- 4. Determine required stock quantity for combo sales
    IF @promotion_type = 'combo-sale'
    BEGIN
        DECLARE @combo_sale_count INT;

        SELECT @combo_sale_count = combo_sale_count
        FROM promotion_product
        WHERE promotion_id = @selected_promotion_id
          AND product_id = @product_id;

        SET @required_stock = @combo_sale_count * @quantity;
    END
    ELSE
    BEGIN
        SET @required_stock = @quantity;
    END

    -- 5. Check if there is sufficient stock
    IF @stock_quantity < @required_stock
    BEGIN
        RAISERROR('Insufficient stock for product ID %d.', 16, 1, @product_id);
        RETURN;
    END

    -- 6. Update product stock
    UPDATE product
    SET stock_quantity = stock_quantity - @required_stock
    WHERE product_id = @product_id;

    -- 7. Update promotion product quantity
    IF @selected_promotion_id IS NOT NULL
    BEGIN
        UPDATE promotion_product
        SET current_quantity = current_quantity - @quantity, quantity_sold = quantity_sold + @quantity
        WHERE promotion_id = @selected_promotion_id
          AND product_id = @product_id;
    END
END;
go

