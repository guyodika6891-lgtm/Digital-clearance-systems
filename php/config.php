<?php
$host = 'localhost:';
$port = '3307';
$dbname = 'clearance_system';
$username = 'root';
$password = '';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    session_start();
} catch(PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}
?>