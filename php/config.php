
<?php
// ============================================
// DATABASE CONFIGURATION
// ============================================

session_start();

$host = 'localhost:';
$port = '3307';
$dbname = 'clearance_system';
$username = 'root';
$password = '';
try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch(PDOException $e) {
    die(json_encode(['success' => false, 'message' => 'Database connection failed: ' . $e->getMessage()]));
}

// ============================================
// AUTHENTICATION FUNCTIONS
// ============================================

function isLoggedIn() {
    return isset($_SESSION['user_id']);
}

function hasRole($role) {
    return isset($_SESSION['role']) && $_SESSION['role'] === $role;
}

function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: ../index.html');
        exit();
    }
}

function requireRole($role) {
    requireLogin();
    if (!hasRole($role) && !hasRole('admin')) {
        header('Location: ../dashboard.html');
        exit();
    }
}
?>
