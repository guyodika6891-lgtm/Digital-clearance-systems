<?php
require_once 'config.php';
requireLogin();

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method');
    }
    
    // Check if user has permission (admin or hod)
    if (!hasRole('admin') && !hasRole('hod')) {
        throw new Exception('You do not have permission to update clearances');
    }
    
    $student_id = $_POST['student_id'] ?? '';
    $department_name = $_POST['department'] ?? '';
    $status = $_POST['status'] ?? '';
    
    if (empty($student_id) || empty($department_name) || empty($status)) {
        throw new Exception('Missing required fields');
    }
    
    if (!in_array($status, ['pending', 'approved', 'rejected', 'cancelled'])) {
        throw new Exception('Invalid status');
    }
    
    $user_id = $_SESSION['user_id'];
    $role = $_SESSION['role'];
    
    // Get department id
    $stmt = $pdo->prepare("SELECT id FROM departments WHERE name = ?");
    $stmt->execute([$department_name]);
    $department = $stmt->fetch();
    
    if (!$department) {
        throw new Exception('Department not found');
    }
    
    // If HOD, verify they are the head of this department
    if ($role === 'hod') {
        $stmt = $pdo->prepare("
            SELECT id FROM departments 
            WHERE id = ? AND head_user_id = ?
        ");
        $stmt->execute([$department['id'], $user_id]);
        if (!$stmt->fetch()) {
            throw new Exception('You are not authorized to manage this department');
        }
    }
    
    // Update clearance
    $cleared_at = ($status === 'approved' || $status === 'rejected') ? 'NOW()' : 'NULL';
    $remarks = ($status === 'rejected') ? 'Rejected by ' . $_SESSION['full_name'] : null;
    
    $stmt = $pdo->prepare("
        UPDATE clearances 
        SET status = ?, 
            cleared_by = ?,
            cleared_at = CASE WHEN ? IN ('approved', 'rejected') THEN NOW() ELSE NULL END,
            remarks = CASE WHEN ? = 'rejected' THEN CONCAT('Rejected by ', ?) ELSE remarks END
        WHERE student_id = ? AND department_id = ?
    ");
    $stmt->execute([$status, $user_id, $status, $status, $_SESSION['full_name'], $student_id, $department['id']]);
    
    echo json_encode(['success' => true, 'message' => 'Clearance updated successfully']);
    
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
