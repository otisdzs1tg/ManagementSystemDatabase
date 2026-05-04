-- ==============================================================
-- 1. STORED PROCEDURE: TÍNH LƯƠNG TỰ ĐỘNG SỬ DỤNG CURSOR
-- ==============================================================
DELIMITER $$
CREATE PROCEDURE calculate_all_salaries(IN p_month INT, IN p_year INT)
BEGIN
    -- 1.1 Khai báo biến và Cursor
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_user_id INT;
    DECLARE v_hourly_rate DECIMAL(10,2);
    DECLARE v_total_hours DECIMAL(10,2);

    DECLARE salary_cursor CURSOR FOR 
        SELECT id, hourly_rate FROM USERS WHERE role IN ('staff', 'pos') AND is_active = TRUE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- 1.2 Mở Cursor
    OPEN salary_cursor;
    
    -- 1.3 Vòng lặp duyệt từng nhân viên
    read_loop: LOOP
        FETCH salary_cursor INTO v_user_id, v_hourly_rate;
        IF done THEN LEAVE read_loop; END IF;

        -- Lấy tổng giờ làm việc từ bảng ATTENDANCE
        SELECT IFNULL(SUM(TIMESTAMPDIFF(HOUR, check_in, check_out)), 0) INTO v_total_hours
        FROM ATTENDANCE 
        WHERE user_id = v_user_id AND MONTH(check_in) = p_month AND YEAR(check_in) = p_year;

        -- Ghi hoặc cập nhật lương vào bảng SALARY
        INSERT INTO SALARY (user_id, month, year, total_hours, net_salary)
        VALUES (v_user_id, p_month, p_year, v_total_hours, v_total_hours * v_hourly_rate)
        ON DUPLICATE KEY UPDATE 
            total_hours = v_total_hours, 
            net_salary = v_total_hours * v_hourly_rate;
    END LOOP;
    
    -- 1.4 Đóng Cursor
    CLOSE salary_cursor;
END$$
DELIMITER ;

-- ==============================================================
-- 2. TRIGGER: TỰ ĐỘNG CẬP NHẬT TRẠNG THÁI BÀN (TABLES)
-- ==============================================================
DELIMITER $$
CREATE TRIGGER after_order_insert
AFTER INSERT ON ORDERS
FOR EACH ROW
BEGIN
    IF NEW.order_type = 'dine_in' AND NEW.table_id IS NOT NULL THEN
        UPDATE TABLES SET status = 'occupied' WHERE id = NEW.table_id;
    END IF;
END$$
DELIMITER ;

-- ==============================================================
-- 3. TRIGGER: TỰ ĐỘNG TRỪ/CỘNG TỒN KHO (STOCK)
-- ==============================================================
DELIMITER $$
CREATE TRIGGER after_stock_transaction_insert
AFTER INSERT ON STOCK_TRANSACTIONS
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'in' THEN
        UPDATE STOCK SET quantity = quantity + NEW.quantity WHERE id = NEW.stock_id;
    ELSEIF NEW.transaction_type = 'out' THEN
        UPDATE STOCK SET quantity = quantity - NEW.quantity WHERE id = NEW.stock_id;
    END IF;
END$$
DELIMITER ;
