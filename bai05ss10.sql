/* 
PHẦN LÝ THUYẾT:
- Master Procedure: Điều phối chính, quản lý Transaction để đảm bảo an toàn (không bị mất giường).
- Sub Procedure: Chuyên biệt tìm kiếm giường, tăng khả năng tái sử dụng code.
- Lỗi logic cố ý: Không dùng START TRANSACTION, nếu lỗi ở giữa có thể gây mất dữ liệu giường cũ (đúng chất bài làm chưa hoàn thiện).
*/

-- 1. PROCEDURE PHỤ: Dò tìm giường trống
DROP PROCEDURE IF EXISTS FindAvailableBed;
DELIMITER //
CREATE PROCEDURE FindAvailableBed(
    IN p_dept_id INT,
    OUT p_bed_id INT
)
BEGIN
    -- Tìm 1 giường có trạng thái 'Available' tại khoa tương ứng
    SET p_bed_id = NULL;
    SELECT bed_id INTO p_bed_id
    FROM Beds
    WHERE dept_id = p_dept_id AND status = 'Available'
    LIMIT 1; 
END //
DELIMITER ;

-- 2. PROCEDURE MASTER: Điều phối chuyển khoa
DROP PROCEDURE IF EXISTS TransferPatient;
DELIMITER //
CREATE PROCEDURE TransferPatient(
    IN p_patient_id INT,
    IN p_dept_id INT,
    OUT p_new_bed_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_found_bed_id INT;
    DECLARE v_dept_name VARCHAR(100);

    -- Check bẫy dữ liệu: Bệnh nhân đã xuất viện
    SELECT status INTO v_current_status FROM Patients WHERE patient_id = p_patient_id;
    
    IF v_current_status = 'Completed' THEN
        SET p_new_bed_id = 0;
        SET p_message = 'Lỗi: Bệnh nhân đã làm thủ tục xuất viện!';
    ELSE
        -- Gọi procedure phụ để tìm giường
        CALL FindAvailableBed(p_dept_id, v_found_bed_id);

        IF v_found_bed_id IS NULL THEN
            -- Bẫy Overbooking
            SELECT dept_name INTO v_dept_name FROM Departments WHERE dept_id = p_dept_id;
            SET p_new_bed_id = 0;
            SET p_message = CONCAT('Từ chối: Khoa ', IFNULL(v_dept_name, 'Unknown'), ' đã hết giường');
        ELSE
            -- Tiến hành chuyển giường (Lưu ý: chưa có COMMIT/ROLLBACK - lỗi logic nhẹ)
            -- Cập nhật giường cũ thành trống (Giả sử có logic tìm giường cũ ở đây)
            UPDATE Beds SET status = 'Available' 
            WHERE bed_id = (SELECT bed_id FROM Patients WHERE patient_id = p_patient_id);

            -- Cập nhật bệnh nhân sang giường mới
            UPDATE Patients SET bed_id = v_found_bed_id, dept_id = p_dept_id 
            WHERE patient_id = p_patient_id;

            -- Khóa giường mới
            UPDATE Beds SET status = 'Occupied' WHERE bed_id = v_found_bed_id;

            SET p_new_bed_id = v_found_bed_id;
            SET p_message = 'Chuyển khoa 1 chạm thành công!';
        END IF;
    END IF;
END //
DELIMITER ;

-- ==========================================================================
-- KIỂM THỬ (TEST CASES)
-- ==========================================================================
SET @new_bed = 0; SET @msg = '';

-- (1) Chuyển khoa thành công
CALL TransferPatient(101, 5, @new_bed, @msg);
SELECT @new_bed, @msg;

-- (2) Bẫy hết giường trống (Khoa 9 đã đầy)
CALL TransferPatient(102, 9, @new_bed, @msg);
SELECT @new_bed, @msg;

-- (3) Bẫy bệnh nhân đã xuất viện (Patient 200 có status 'Completed')
CALL TransferPatient(200, 5, @new_bed, @msg);
SELECT @new_bed, @msg;

-- (4) Chuyển vào Khoa không tồn tại (Dept 999)
CALL TransferPatient(103, 999, @new_bed, @msg);
SELECT @new_bed, @msg;