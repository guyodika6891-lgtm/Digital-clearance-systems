<?php
require_once 'config.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method');
    }
    
    $student_id = trim($_POST['student_id'] ?? '');
    $full_name = trim($_POST['full_name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $role = $_POST['role'] ?? 'student';
    
    // Validation
    if (empty($student_id) || empty($full_name) || empty($email) || empty($password)) {
        throw new Exception('All fields are required');
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }
    
    if (strlen($password) < 6) {
        throw new Exception('Password must be at least 6 characters');
    }
    
    // Check if student_id exists
    $stmt = $pdo->prepare("SELECT id FROM users WHERE student_id = ?");
    $stmt->execute([$student_id]);
    if ($stmt->fetch()) {
        throw new Exception('Student ID already exists');
    }
    
    // Check if email exists
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        throw new Exception('Email already exists');
    }
    
    $hashed_password = password_hash($password, PASSWORD_DEFAULT);
    
    $pdo->beginTransaction();
    
    $stmt = $pdo->prepare("
        INSERT INTO users (student_id, full_name, email, password, role) 
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt->execute([$student_id, $full_name, $email, $hashed_password, $role]);
    
    $pdo->commit();
    
    echo json_encode(['success' => true, 'message' => 'Registration successful! Please login.']);
    
} catch(PDOException $e) {
    $pdo->rollBack();
    if ($e->getCode() == 23000) {
        echo json_encode(['success' => false, 'message' => 'Student ID or Email already exists']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    }
} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
