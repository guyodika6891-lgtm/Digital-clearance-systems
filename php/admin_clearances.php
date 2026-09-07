<?php
require_once 'config.php';
requireRole('admin');

header('Content-Type: application/json');

try {
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
    
    echo json_encode($stmt->fetchAll());
    
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>
