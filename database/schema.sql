-- =============================================
-- COMPLETE DATABASE SETUP - FIXED VERSION
-- =============================================

-- First, create and select database
CREATE DATABASE IF NOT EXISTS clearance_system 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE clearance_system;

-- =============================================
-- DROP ALL EXISTING OBJECTS (if any)
-- =============================================

DROP VIEW IF EXISTS student_clearance_status;
DROP VIEW IF EXISTS department_clearance_summary;
DROP VIEW IF EXISTS student_overall_status;
DROP PROCEDURE IF EXISTS create_student_clearances;
DROP FUNCTION IF EXISTS get_clearance_progress;
DROP TRIGGER IF EXISTS after_user_insert;
DROP TABLE IF EXISTS clearance_documents;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS password_resets;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS clearances;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS users;

-- =============================================
-- CREATE TABLES IN CORRECT ORDER
-- =============================================

-- 1. Users table (no foreign keys yet)
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('student', 'hod', 'admin', 'staff') DEFAULT 'student',
    department_id INT NULL,  -- Will add foreign key after departments created
    profile_picture VARCHAR(255) NULL,
    is_active TINYINT(1) DEFAULT 1,
    email_verified_at TIMESTAMP NULL,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_student_id (student_id),
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_active (is_active)
);

-- 2. Departments table
CREATE TABLE departments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    head_name VARCHAR(100),
    head_user_id INT NULL,
    description TEXT,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    FOREIGN KEY (head_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- 3. Add foreign key to users table (now that departments exists)
ALTER TABLE users
ADD FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;

-- 4. Clearances table
CREATE TABLE clearances (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(20) NOT NULL,
    department_id INT NOT NULL,
    status ENUM('pending', 'approved', 'rejected', 'cancelled') DEFAULT 'pending',
    priority ENUM('normal', 'urgent') DEFAULT 'normal',
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT,
    rejection_reason TEXT NULL,
    cleared_by INT NULL,
    cleared_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_student_dept (student_id, department_id),
    INDEX idx_status (status),
    INDEX idx_cleared_by (cleared_by),
    INDEX idx_student_status (student_id, status),
    INDEX idx_department_status (department_id, status),
    FOREIGN KEY (student_id) REFERENCES users(student_id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
    FOREIGN KEY (cleared_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY unique_clearance (student_id, department_id)
);

-- 5. Audit logs table
CREATE TABLE audit_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id INT,
    old_data JSON,
    new_data JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 6. Notifications table
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'success', 'warning', 'danger') DEFAULT 'info',
    is_read TINYINT(1) DEFAULT 0,
    related_clearance_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_unread (user_id, is_read),
    INDEX idx_created (created_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (related_clearance_id) REFERENCES clearances(id) ON DELETE SET NULL
);

-- 7. Clearance documents table
CREATE TABLE clearance_documents (
    id INT PRIMARY KEY AUTO_INCREMENT,
    clearance_id INT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(50),
    uploaded_by INT NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (clearance_id) REFERENCES clearances(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE CASCADE
);

-- 8. Password resets table
CREATE TABLE password_resets (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(100) NOT NULL,
    token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email_token (email, token)
);

-- 9. Settings table
CREATE TABLE settings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    description VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =============================================
-- STORED PROCEDURE
-- =============================================

DELIMITER //

CREATE PROCEDURE create_student_clearances(IN p_student_id VARCHAR(20))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE dept_id INT;
    DECLARE dept_cursor CURSOR FOR SELECT id FROM departments WHERE is_active = 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN dept_cursor;
    
    read_loop: LOOP
        FETCH dept_cursor INTO dept_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        INSERT IGNORE INTO clearances (student_id, department_id, status)
        VALUES (p_student_id, dept_id, 'pending');
    END LOOP;
    
    CLOSE dept_cursor;
END //

DELIMITER ;

-- =============================================
-- TRIGGER
-- =============================================

DELIMITER //

CREATE TRIGGER after_user_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    IF NEW.role = 'student' THEN
        CALL create_student_clearances(NEW.student_id);
    END IF;
END //

DELIMITER ;

-- =============================================
-- VIEWS
-- =============================================

CREATE VIEW student_clearance_status AS
SELECT 
    u.student_id,
    u.full_name,
    u.email,
    u.phone,
    d.name AS department_name,
    d.head_name AS department_head,
    c.status,
    c.priority,
    c.remarks,
    c.rejection_reason,
    c.cleared_at,
    CONCAT(cleared_by_user.full_name) AS cleared_by_name
FROM clearances c
JOIN users u ON c.student_id = u.student_id
JOIN departments d ON c.department_id = d.id
LEFT JOIN users cleared_by_user ON c.cleared_by = cleared_by_user.id;

CREATE VIEW department_clearance_summary AS
SELECT 
    d.id AS department_id,
    d.name AS department_name,
    COUNT(CASE WHEN c.status = 'pending' THEN 1 END) AS pending_count,
    COUNT(CASE WHEN c.status = 'approved' THEN 1 END) AS approved_count,
    COUNT(CASE WHEN c.status = 'rejected' THEN 1 END) AS rejected_count,
    COUNT(CASE WHEN c.status = 'cancelled' THEN 1 END) AS cancelled_count,
    COUNT(*) AS total_count
FROM departments d
LEFT JOIN clearances c ON d.id = c.department_id
WHERE d.is_active = 1
GROUP BY d.id, d.name;

CREATE VIEW student_overall_status AS
SELECT 
    u.student_id,
    u.full_name,
    u.email,
    COUNT(DISTINCT d.id) AS total_departments,
    COUNT(DISTINCT CASE WHEN c.status = 'approved' THEN d.id END) AS cleared_departments,
    COUNT(DISTINCT CASE WHEN c.status = 'pending' THEN d.id END) AS pending_departments,
    COUNT(DISTINCT CASE WHEN c.status = 'rejected' THEN d.id END) AS rejected_departments,
    CASE 
        WHEN COUNT(DISTINCT d.id) = COUNT(DISTINCT CASE WHEN c.status = 'approved' THEN d.id END) 
        THEN 'Fully Cleared'
        WHEN COUNT(DISTINCT CASE WHEN c.status = 'rejected' THEN d.id END) > 0 
        THEN 'Has Rejections'
        ELSE 'In Progress'
    END AS overall_status,
    get_clearance_progress(u.student_id) AS progress_percentage
FROM users u
CROSS JOIN departments d
LEFT JOIN clearances c ON u.student_id = c.student_id AND d.id = c.department_id
WHERE u.role = 'student' AND u.is_active = 1
GROUP BY u.id;

-- =============================================
-- FUNCTION
-- =============================================

DELIMITER //

CREATE FUNCTION get_clearance_progress(p_student_id VARCHAR(20))
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE total_depts INT DEFAULT 0;
    DECLARE cleared_depts INT DEFAULT 0;
    
    SELECT COUNT(*) INTO total_depts FROM departments WHERE is_active = 1;
    
    IF total_depts = 0 THEN
        RETURN 0.00;
    END IF;
    
    SELECT COUNT(*) INTO cleared_depts
    FROM clearances
    WHERE student_id = p_student_id AND status = 'approved';
    
    RETURN ROUND((cleared_depts / total_depts) * 100, 2);
END //

DELIMITER ;

-- =============================================
-- INSERT SAMPLE DATA
-- =============================================

-- Insert users
INSERT INTO users (student_id, full_name, email, phone, password, role, is_active) VALUES
('admin001', 'System Admin', 'admin@school.edu', '+1234567890', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 1),
('hod001', 'Dr. Smith', 'hod.library@school.edu', '+1234567891', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('hod002', 'Mr. Johnson', 'hod.finance@school.edu', '+1234567892', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('hod003', 'Prof. Williams', 'hod.academic@school.edu', '+1234567893', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('hod004', 'Coach Davis', 'hod.sports@school.edu', '+1234567894', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('hod005', 'Ms. Garcia', 'hod.it@school.edu', '+1234567895', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('hod006', 'Dr. Brown', 'hod.registrar@school.edu', '+1234567896', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('hod007', 'Mrs. Taylor', 'hod.studentaffairs@school.edu', '+1234567897', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod', 1),
('STU2024001', 'John Doe', 'john.doe@school.edu', '+1234567898', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student', 1),
('STU2024002', 'Jane Smith', 'jane.smith@school.edu', '+1234567899', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student', 1),
('STU2024003', 'Bob Johnson', 'bob.johnson@school.edu', '+1234567800', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student', 1),
('STU2024004', 'Alice Williams', 'alice.williams@school.edu', '+1234567801', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student', 1),
('STU2024005', 'Charlie Brown', 'charlie.brown@school.edu', '+1234567802', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student', 1),
('STU2024006', 'Diana Prince', 'diana.prince@school.edu', '+1234567803', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student', 1);

-- Insert departments
INSERT INTO departments (name, head_name, head_user_id, description, is_active) VALUES
('Library', 'Dr. Smith', (SELECT id FROM users WHERE student_id = 'hod001'), 'Library and resource center - Manages books, journals, and study materials', 1),
('Finance', 'Mr. Johnson', (SELECT id FROM users WHERE student_id = 'hod002'), 'Financial services - Handles tuition fees, scholarships, and financial aid', 1),
('Academic', 'Prof. Williams', (SELECT id FROM users WHERE student_id = 'hod003'), 'Academic affairs - Manages courses, grades, and academic records', 1),
('Sports', 'Coach Davis', (SELECT id FROM users WHERE student_id = 'hod004'), 'Sports and athletics - Oversees sports activities and facilities', 1),
('IT Services', 'Ms. Garcia', (SELECT id FROM users WHERE student_id = 'hod005'), 'Information technology - Manages computer labs, network, and systems', 1),
('Registrar', 'Dr. Brown', (SELECT id FROM users WHERE student_id = 'hod006'), 'Registrar office - Handles enrollment, transcripts, and student records', 1),
('Student Affairs', 'Mrs. Taylor', (SELECT id FROM users WHERE student_id = 'hod007'), 'Student services - Manages student welfare, activities, and support', 1);

-- Create clearances for existing students
CALL create_student_clearances('STU2024001');
CALL create_student_clearances('STU2024002');
CALL create_student_clearances('STU2024003');
CALL create_student_clearances('STU2024004');
CALL create_student_clearances('STU2024005');
CALL create_student_clearances('STU2024006');

-- Update some clearances to approved for demonstration
UPDATE clearances 
SET status = 'approved', 
    cleared_by = (SELECT id FROM users WHERE student_id = 'admin001'),
    cleared_at = NOW()
WHERE student_id = 'STU2024001' 
AND department_id IN (SELECT id FROM departments WHERE name IN ('Library', 'Finance'));

-- Update some clearances to rejected for demonstration
UPDATE clearances 
SET status = 'rejected', 
    remarks = 'Outstanding library books need to be returned',
    rejection_reason = 'Student has overdue books',
    cleared_by = (SELECT id FROM users WHERE student_id = 'hod001'),
    cleared_at = NOW()
WHERE student_id = 'STU2024002' 
AND department_id = (SELECT id FROM departments WHERE name = 'Library');

-- Update some clearances to urgent
UPDATE clearances 
SET priority = 'urgent'
WHERE student_id = 'STU2024001' 
AND department_id IN (SELECT id FROM departments WHERE name IN ('Sports', 'IT Services'));

-- Insert settings
INSERT INTO settings (setting_key, setting_value, description) VALUES
('system_name', 'ClearanceHub', 'Name of the system'),
('allow_student_self_request', '1', 'Allow students to request clearance'),
('require_document_upload', '0', 'Force document upload before approval'),
('notification_email', 'noreply@school.edu', 'System notification email');

-- =============================================
-- VERIFY DATA
-- =============================================

SELECT '========== USERS ==========' AS '';
SELECT id, student_id, full_name, email, phone, role, is_active FROM users ORDER BY role, student_id;

SELECT '========== DEPARTMENTS ==========' AS '';
SELECT * FROM departments;

SELECT '========== CLEARANCES ==========' AS '';
SELECT c.id, u.student_id, u.full_name, d.name AS department, c.status, c.priority, c.remarks, c.rejection_reason
FROM clearances c
JOIN users u ON c.student_id = u.student_id
JOIN departments d ON c.department_id = d.id
ORDER BY u.student_id, d.name;

SELECT '========== STUDENT OVERALL STATUS ==========' AS '';
SELECT * FROM student_overall_status;

SELECT '========== DEPARTMENT CLEARANCE SUMMARY ==========' AS '';
SELECT * FROM department_clearance_summary;

SELECT '========== CLEARANCE PROGRESS ==========' AS '';
SELECT 
    student_id, 
    full_name,
    get_clearance_progress(student_id) AS progress_percentage
FROM users 
WHERE role = 'student' AND is_active = 1;

SELECT '========== SETTINGS ==========' AS '';
SELECT * FROM settings;

-- =============================================
-- COMPLETION MESSAGE
-- =============================================
SELECT '=============================================' AS '';
SELECT '    DATABASE SETUP COMPLETE!' AS '';
SELECT '=============================================' AS '';
SELECT 'Admin Login:   admin001   / password123' AS '';
SELECT 'HOD Login:     hod001     / password123' AS '';
SELECT 'Student Login: STU2024001 / password123' AS '';
SELECT '=============================================' AS '';
SELECT 'ALL TABLES CREATED SUCCESSFULLY!' AS '';
SELECT '=============================================' AS '';
