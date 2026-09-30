<?php
declare(strict_types=1);

$validCamera = '04';
$validToken = 'VT217-AURORA-CAM04';
$camera = isset($_GET['camera']) ? trim((string) $_GET['camera']) : '';
$token = isset($_GET['token']) ? trim((string) $_GET['token']) : '';

if (!hash_equals($validCamera, $camera) || !hash_equals($validToken, $token)) {
    http_response_code(403);
    header('Content-Type: text/plain; charset=UTF-8');
    exit("VAULT-TEC SECURITY ARCHIVE\nACCESS DENIED\n");
}

$image = '/vault217/security/camera_archive/cam04.jpg';
if (!is_readable($image)) {
    http_response_code(503);
    header('Content-Type: text/plain; charset=UTF-8');
    exit("ARCHIVE TEMPORARILY UNAVAILABLE\n");
}

header('Content-Type: image/jpeg');
header('Content-Length: ' . (string) filesize($image));
header('Content-Disposition: attachment; filename="cam04.jpg"');
header('X-Content-Type-Options: nosniff');
readfile($image);
