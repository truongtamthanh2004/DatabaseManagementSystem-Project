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
    -- Hủy các chương trình khuyến mãi đã hết hạn hoặc hết số lượng
    DELETE FROM promotion_product
    WHERE current_quantity = 0 
       OR EXISTS (
           SELECT 1 
           FROM promotion p 
           WHERE p.promotion_id = promotion_product.promotion_id 
           AND p.end_date < GETDATE()
       );
END;
go

