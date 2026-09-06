CREATE DATABASE clearance_systems;
USE clearance_system;

-- Users table
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('student', 'hod', 'admin') DEFAULT 'student',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Departments table
CREATE TABLE departments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    head_name VARCHAR(100)
);

-- Clearance status table
CREATE TABLE clearances (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(20) NOT NULL,
    department_id INT NOT NULL,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    remarks TEXT,
    cleared_by INT,
    cleared_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES users(student_id),
    FOREIGN KEY (department_id) REFERENCES departments(id),
    FOREIGN KEY (cleared_by) REFERENCES users(id)
);

-- Insert sample departments
INSERT INTO departments (name, head_name) VALUES
('Library', 'Dr. Smith'),
('Finance', 'Mr. Johnson'),
('Academic', 'Prof. Williams'),
('Sports', 'Coach Davis'),
('IT Services', 'Ms. Garcia');