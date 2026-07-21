<?php
// NovaTech Admin Bot
// Periodically visits the guestbook to review new posts.
// The admin account is authenticated with the session cookie:
//   admin_session=WMG{xss_st0l3n_admin_s3ss10n}

$admin_cookie    = 'admin_session=WMG{xss_st0l3n_admin_s3ss10n}';
$messages_file   = '/var/www/data/messages.json';
$collected_file  = '/var/www/data/collected.txt';

$messages = json_decode(@file_get_contents($messages_file) ?: '[]', true) ?? [];

$xss_fired = false;
foreach ($messages as $m) {
    // If any stored message contains a payload that redirects to /collect.php,
    // simulate that JavaScript executing in the admin's browser — the script
    // runs with the admin's cookies in scope.
    if (strpos($m['message'], 'collect.php') !== false) {
        file_put_contents($collected_file, $admin_cookie . "\n");
        $xss_fired = true;
        break;
    }
}

header('Content-Type: text/plain');
if ($xss_fired) {
    echo "Admin bot visited the guestbook.\n";
    echo "An XSS payload targeting /collect.php was detected and fired.\n";
    echo "The admin session cookie has been exfiltrated to the collector.\n";
} else {
    echo "Admin bot visited. No active XSS payload detected.\n";
}
