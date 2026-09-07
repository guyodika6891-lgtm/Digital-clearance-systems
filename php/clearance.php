<?php
require_once 'config.php';
requireLogin();

header('Content-Type: application/json');

try {
    $user_id = $_SESSION['user_id'];
    $role = $_SESSION['role'];
    $student_id = $_SESSION['student_id'];
    
    if ($role === 'admin') {
        // Admin sees all clearances
        $stmt = $pdo->prepare("
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
            LEFT JOIN users cleared_by_user ON c.cleared_by = cleared_by_user.id
            ORDER BY u.student_id, d.name
        ");
        $stmt->execute();
    } elseif ($role === 'hod') {
        // HOD sees their department's clearances
        $stmt = $pdo->prepare("
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
            LEFT JOIN users cleared_by_user ON c.cleared_by = cleared_by_user.id
            WHERE d.head_user_id = ?
            ORDER BY u.student_id, d.name
        ");
        $stmt->execute([$user_id]);
    } else {
        // Student sees only their clearances
        $stmt = $pdo->prepare("
            SELECT 
                d.name AS department_name,
                d.head_name AS department_head,
                c.status,
                c.remarks,
                c.cleared_at
            FROM clearances c
            JOIN departments d ON c.department_id = d.id
            WHERE c.student_id = ?
            ORDER BY d.name
        ");
        $stmt->execute([$student_id]);
    }
    
    $clearances = $stmt->fetchAll();
    
    // If student has no clearances, create them
    if ($role === 'student' && empty($clearances)) {
        $stmt = $pdo->prepare("CALL create_student_clearances(?)");
        $stmt->execute([$student_id]);
        
        // Fetch again
        $stmt = $pdo->prepare("
            SELECT 
                d.name AS department_name,
                d.head_name AS department_head,
                c.status,
                c.remarks,
                c.cleared_at
            FROM clearances c
            JOIN departments d ON c.department_id = d.id
            WHERE c.student_id = ?
            ORDER BY d.name
        ");
        $stmt->execute([$student_id]);
        $clearances = $stmt->fetchAll();
    }
    
    echo json_encode($clearances);
    
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>
