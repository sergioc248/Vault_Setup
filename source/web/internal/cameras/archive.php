<?php
declare(strict_types=1);

$validCamera = '04';
$validToken = 'VT217-AURORA-CAM04';
$camera = isset($_POST['camera']) ? trim((string) $_POST['camera']) : '';
$token = isset($_POST['token']) ? trim((string) $_POST['token']) : '';
$submitted = $_SERVER['REQUEST_METHOD'] === 'POST';
$granted = $submitted && hash_equals($validCamera, $camera) && hash_equals($validToken, $token);
if ($submitted && !$granted) {
    http_response_code(403);
}
?>
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Security Camera Archive</title><link rel="stylesheet" href="/assets/css/vault.css"></head>
<body><main><p class="muted">VAULT-TEC SECURITY ARCHIVE // RESEARCH LEVEL B</p><h1>Security Camera Archive</h1>
<?php if ($granted): ?>
<p class="warning">ACCESS GRANTED</p>
<pre>VAULT: 217
CAMERA: 04
TIMESTAMP: 2077-10-22 23:41:17
ARCHIVE: cam04.jpg

This image was recovered immediately before JANUS initiated lockdown.

SECURITY VERIFICATION:
VaultTec{The_Wire_Remembers}</pre>
<p><a href="/internal/cameras/download.php?camera=04&amp;token=<?= rawurlencode($validToken) ?>">[ Download cam04.jpg ]</a></p>
<?php else: ?>
<p class="warning"><?= $submitted ? 'ACCESS DENIED — INVALID ARCHIVE CREDENTIALS' : 'ACCESS DENIED — ARCHIVE TOKEN REQUIRED' ?></p>
<form method="post" action="/internal/cameras/archive.php">
<p><label>Camera ID:<br><input name="camera" required autocomplete="off"></label></p>
<p><label>Archive Token:<br><input name="token" required autocomplete="off"></label></p>
<p><button type="submit">[ Authenticate ]</button></p>
</form>
<?php endif; ?>
<p><a href="/">[ Return to public terminal ]</a></p></main></body></html>
