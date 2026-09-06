<?php
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $student_id = $_POST['student_id'];
    $full_name = $_POST['full_name'];
    $email = $_POST['email'];
    $password = password_hash($_POST['password'], PASSWORD_DEFAULT);
    $role = $_POST['role'] ?? 'student';
    
    try {
        $stmt = $pdo->prepare("INSERT INTO users (student_id, full_name, email, password, role) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$student_id, $full_name, $email, $password, $role]);
        echo json_encode(['success' => true, 'message' => 'Registration successful']);
    } catch(PDOException $e) {
        echo json_encode(['success' => false, 'message' => 'Student ID or Email already exists']);
    }
}
?>