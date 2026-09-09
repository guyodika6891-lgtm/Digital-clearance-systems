<?php
// ============================================
// DATABASE CONFIGURATION - WORKING
// ============================================

// Start session if not already started
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Database settings - MATCH YOUR XAMPP SETUP
$host = 'localhost:';     // or 'localhost'
$port = '3307';          // Default MySQL port
$dbname = 'clearance_system';
$username = 'root';
$password = '';          // Default XAMPP has no password

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    // Create connection with proper options
    $pdo = new PDO(
        "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_TIMEOUT => 10,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
        ]
    );
    
    // Test connection
    $pdo->query("SELECT 1");
    
} catch(PDOException $e) {
    // Try localhost as fallback
    try {
        $host = 'localhost';
        $pdo = new PDO(
            "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4",
            $username,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_TIMEOUT => 10
            ]
        );
    } catch(PDOException $e2) {
        // Return JSON error for AJAX requests
        if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && 
            strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') {
            header('Content-Type: application/json');
            die(json_encode([
                'success' => false, 
                'message' => 'Database connection failed. Please check: MySQL is running in XAMPP.'
            ]));
        } else {
            die("Database connection failed: " . $e2->getMessage());
        }
    }
}

// ============================================
// AUTHENTICATION FUNCTIONS
// ============================================

function isLoggedIn() {
    return isset($_SESSION['user_id']) && !empty($_SESSION['user_id']);
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

// Optional: Function to check if database exists
function checkDatabase() {
    global $pdo;
    try {
        $pdo->query("SELECT 1 FROM users LIMIT 1");
        return true;
    } catch (PDOException $e) {
        return false;
    }
}
?>
