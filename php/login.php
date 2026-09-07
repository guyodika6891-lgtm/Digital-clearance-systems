<?php
require_once 'config.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method');
    }
    
    $student_id = $_POST['student_id'] ?? '';
    $password = $_POST['password'] ?? '';
    
    if (empty($student_id) || empty($password)) {
        throw new Exception('Please fill in all fields');
    }
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE student_id = ?");
    $stmt->execute([$student_id]);
    $user = $stmt->fetch();
    
    if ($user && password_verify($password, $user['password'])) {
        // Update last login
        $stmt = $pdo->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
        $stmt->execute([$user['id']]);
        
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['student_id'] = $user['student_id'];
        $_SESSION['full_name'] = $user['full_name'];
        $_SESSION['role'] = $user['role'];
        $_SESSION['email'] = $user['email'];
        
        // Redirect based on role
        $redirect = 'dashboard.html';
        if ($user['role'] === 'admin') {
            $redirect = 'admin_dashboard.html';
        } elseif ($user['role'] === 'hod') {
            $redirect = 'hod_dashboard.html';
        }
        
        echo json_encode([
            'success' => true,
            'role' => $user['role'],
            'redirect' => $redirect
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Invalid Student ID or Password']);
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
