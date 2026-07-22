<?php
// Northgate Veterinary Clinic — Patient ID lookup portal
// (Intentionally vulnerable to SQL injection — training environment only)
error_reporting(0);
$db = new SQLite3('/var/www/db/clinic.db');
$id = isset($_GET['id']) ? $_GET['id'] : '0';
$row = @$db->querySingle("SELECT name FROM patients WHERE id = " . $id);
echo $row
    ? "Patient found: " . htmlspecialchars($row, ENT_QUOTES, 'UTF-8')
    : "No record found.";
