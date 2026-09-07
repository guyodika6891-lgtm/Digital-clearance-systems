<?php
require_once 'config.php';
requireLogin();

header('Content-Type: application/json');

echo json_encode([
    'success' => true,
    'full_name' => $_SESSION['full_name'],
    'role' => $_SESSION['role'],
    'student_id' => $_SESSION['student_id'],
    'email' => $_SESSION['email']
]);
?>
