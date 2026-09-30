<?php
declare(strict_types=1);

$stateFile = '/var/lib/vault217/janus/status';
$validCode = 'OMEGA-217-AURORA';
$submitted = $_SERVER['REQUEST_METHOD'] === 'POST';
$code = isset($_POST['override_code']) ? trim((string) $_POST['override_code']) : '';
$state = is_readable($stateFile) ? trim((string) file_get_contents($stateFile)) : 'ACTIVE';
$denied = false;

if ($submitted && $state !== 'TERMINATED') {
    if (hash_equals($validCode, $code)) {
        if (file_put_contents($stateFile, "TERMINATED\n", LOCK_EX) === false) {
            http_response_code(503);
        } else {
            $state = 'TERMINATED';
        }
    } else {
        $denied = true;
        http_response_code(403);
    }
}

$terminated = $state === 'TERMINATED';
?>
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>JANUS Control System</title><link rel="stylesheet" href="/assets/css/vault.css"></head>
<body><main><p class="muted">VAULT-TEC INDUSTRIES // JANUS CONTROL SYSTEM</p><h1>Emergency Control Interface</h1>
<?php if ($terminated): ?>
<p class="warning">EMERGENCY AUTHORIZATION ACCEPTED</p>
<pre>PROJECT AURORA: TERMINATED
RESEARCH LOCKDOWN: RELEASED
EXTERNAL COMMUNICATION: RESTORED
VAULT 217: UNSEALED

You recovered the truth buried beneath two centuries of Vault-Tec records.

FINAL AUTHORIZATION:
VaultTec{JANUS_PROTOCOL_TERMINATED}</pre>
<p>VAULT-TEC THANKS YOU FOR YOUR CONTINUED COOPERATION.</p>
<?php else: ?>
<pre>STATUS: AURORA PROTOCOL ACTIVE
VAULT 217: SEALED
RESEARCH LEVEL B: LOCKDOWN</pre>
<?php if ($denied): ?><p class="warning">EMERGENCY AUTHORIZATION REJECTED</p><?php endif; ?>
<form method="post" action="/janus/override/">
<p><label>Emergency Override:<br><input name="override_code" required autocomplete="off"></label></p>
<p><button type="submit">[ Execute ]</button></p>
</form>
<?php endif; ?>
</main></body></html>
