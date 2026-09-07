-- =============================================
-- COMPLETE RESET AND RECREATE
-- =============================================

-- First, select the database
USE clearance_system;

-- Drop all objects in the correct order
DROP VIEW IF EXISTS student_clearance_status;
DROP VIEW IF EXISTS department_clearance_summary;
DROP VIEW IF EXISTS student_overall_status;
DROP PROCEDURE IF EXISTS create_student_clearances;
DROP FUNCTION IF EXISTS get_clearance_progress;
DROP TRIGGER IF EXISTS after_user_insert;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS clearances;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS users;

-- =============================================
-- RECREATE EVERYTHING
-- =============================================

-- Create users table
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('student', 'hod', 'admin', 'staff') DEFAULT 'student',
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_student_id (student_id),
    INDEX idx_email (email),
    INDEX idx_role (role)
);

-- Create departments table
CREATE TABLE departments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    head_name VARCHAR(100),
    head_user_id INT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    FOREIGN KEY (head_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Create clearances table
CREATE TABLE clearances (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(20) NOT NULL,
    department_id INT NOT NULL,
    status ENUM('pending', 'approved', 'rejected', 'cancelled') DEFAULT 'pending',
    remarks TEXT,
    cleared_by INT NULL,
    cleared_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_student_dept (student_id, department_id),
    INDEX idx_status (status),
    INDEX idx_cleared_by (cleared_by),
    FOREIGN KEY (student_id) REFERENCES users(student_id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
    FOREIGN KEY (cleared_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY unique_clearance (student_id, department_id)
);

-- Create audit_logs table (optional)
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

-- Create stored procedure
DELIMITER //

CREATE PROCEDURE create_student_clearances(IN p_student_id VARCHAR(20))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE dept_id INT;
    DECLARE dept_cursor CURSOR FOR SELECT id FROM departments;
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

-- Create trigger
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

-- Create views
CREATE VIEW student_clearance_status AS
SELECT 
    u.student_id,
    u.full_name,
    u.email,
    d.name AS department_name,
    d.head_name AS department_head,
    c.status,
    c.remarks,
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
    COUNT(*) AS total_count
FROM departments d
LEFT JOIN clearances c ON d.id = c.department_id
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
    END AS overall_status
FROM users u
CROSS JOIN departments d
LEFT JOIN clearances c ON u.student_id = c.student_id AND d.id = c.department_id
WHERE u.role = 'student'
GROUP BY u.id;

-- Create function
DELIMITER //

CREATE FUNCTION get_clearance_progress(p_student_id VARCHAR(20))
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total_depts INT;
    DECLARE cleared_depts INT;
    DECLARE progress INT;
    
    SELECT COUNT(*) INTO total_depts FROM departments;
    SELECT COUNT(DISTINCT department_id) INTO cleared_depts 
    FROM clearances 
    WHERE student_id = p_student_id AND status = 'approved';
    
    IF total_depts > 0 THEN
        SET progress = ROUND((cleared_depts / total_depts) * 100);
    ELSE
        SET progress = 0;
    END IF;
    
    RETURN progress;
END //

DELIMITER ;

-- Insert sample data
INSERT INTO users (student_id, full_name, email, password, role) VALUES
('admin001', 'System Admin', 'admin@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin'),
('hod001', 'Dr. Smith', 'hod.library@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('hod002', 'Mr. Johnson', 'hod.finance@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('hod003', 'Prof. Williams', 'hod.academic@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('hod004', 'Coach Davis', 'hod.sports@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('hod005', 'Ms. Garcia', 'hod.it@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('hod006', 'Dr. Brown', 'hod.registrar@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('hod007', 'Mrs. Taylor', 'hod.studentaffairs@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'hod'),
('STU2024001', 'John Doe', 'john.doe@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student'),
('STU2024002', 'Jane Smith', 'jane.smith@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student'),
('STU2024003', 'Bob Johnson', 'bob.johnson@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student'),
('STU2024004', 'Alice Williams', 'alice.williams@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student'),
('STU2024005', 'Charlie Brown', 'charlie.brown@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student'),
('STU2024006', 'Diana Prince', 'diana.prince@school.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student');

-- Insert departments
INSERT INTO departments (name, head_name, head_user_id, description) VALUES
('Library', 'Dr. Smith', (SELECT id FROM users WHERE student_id = 'hod001'), 'Library and resource center - Manages books, journals, and study materials'),
('Finance', 'Mr. Johnson', (SELECT id FROM users WHERE student_id = 'hod002'), 'Financial services - Handles tuition fees, scholarships, and financial aid'),
('Academic', 'Prof. Williams', (SELECT id FROM users WHERE student_id = 'hod003'), 'Academic affairs - Manages courses, grades, and academic records'),
('Sports', 'Coach Davis', (SELECT id FROM users WHERE student_id = 'hod004'), 'Sports and athletics - Oversees sports activities and facilities'),
('IT Services', 'Ms. Garcia', (SELECT id FROM users WHERE student_id = 'hod005'), 'Information technology - Manages computer labs, network, and systems'),
('Registrar', 'Dr. Brown', (SELECT id FROM users WHERE student_id = 'hod006'), 'Registrar office - Handles enrollment, transcripts, and student records'),
('Student Affairs', 'Mrs. Taylor', (SELECT id FROM users WHERE student_id = 'hod007'), 'Student services - Manages student welfare, activities, and support');

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
    cleared_by = (SELECT id FROM users WHERE student_id = 'hod001'),
    cleared_at = NOW()
WHERE student_id = 'STU2024002' 
AND department_id = (SELECT id FROM departments WHERE name = 'Library');

-- =============================================
-- VERIFY DATA
-- =============================================

SELECT '========== USERS ==========' AS '';
SELECT id, student_id, full_name, email, role FROM users ORDER BY role, student_id;

SELECT '========== DEPARTMENTS ==========' AS '';
SELECT * FROM departments;

SELECT '========== CLEARANCES ==========' AS '';
SELECT c.id, u.student_id, u.full_name, d.name AS department, c.status, c.remarks, c.cleared_at
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
WHERE role = 'student';

-- =============================================
-- COMPLETION MESSAGE
-- =============================================
SELECT '=============================================' AS '';
SELECT 'DATABASE SETUP COMPLETE!' AS '';
SELECT '=============================================' AS '';
SELECT 'Default Admin Login: admin001 / password123' AS '';
SELECT 'Default HOD Login: hod001 / password123' AS '';
SELECT 'Default Student Login: STU2024001 / password123' AS '';
SELECT '=============================================' AS '';
