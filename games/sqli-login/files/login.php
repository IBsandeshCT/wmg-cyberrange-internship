<?php
// Pinnacle Finance — Employee Portal
// INTENTIONALLY VULNERABLE: user input is concatenated directly into the SQL query.
$db = new SQLite3('/var/www/db/app.db');
$db->enableExceptions(true);
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    try {
        // VULNERABLE: $username and $password are not sanitised.
        $user = $db->querySingle(
            "SELECT username FROM users WHERE username='$username' AND password='$password'"
        );
        if ($user !== null) {
            $flag = $db->querySingle("SELECT flag FROM secrets LIMIT 1");
            $message = '<p class="ok">Welcome, ' . htmlspecialchars($user) . '! ' . $flag . '</p>';
        } else {
            $message = '<p class="err">Invalid credentials. Please try again.</p>';
        }
    } catch (Exception $e) {
        $message = '<p class="err">Database error: ' . htmlspecialchars($e->getMessage()) . '</p>';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Pinnacle Finance — Employee Portal</title>
<style>
  body  { font-family: Arial, sans-serif; background: #f0f4f8;
          display: flex; justify-content: center; padding-top: 80px; }
  .box  { background: white; padding: 40px; border-radius: 8px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.15); width: 340px; }
  h2    { margin: 0 0 4px; color: #003366; }
  h3    { margin: 0 0 24px; color: #555; font-weight: normal; }
  label { display: block; font-size: 0.85em; color: #333; margin-bottom: 2px; }
  input { display: block; width: 100%; padding: 8px; margin-bottom: 14px;
          border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
  button { width: 100%; padding: 10px; background: #003366; color: white;
           border: none; border-radius: 4px; cursor: pointer; font-size: 1em; }
  .ok  { color: #1a6b1a; background: #eafaea; padding: 10px;
          border-radius: 4px; margin-top: 14px; }
  .err { color: #8b0000; background: #fdecea; padding: 10px;
          border-radius: 4px; margin-top: 14px; word-break: break-all; }
</style>
</head>
<body>
<div class="box">
  <h2>Pinnacle Finance</h2>
  <h3>Employee Portal</h3>
  <form method="POST" action="">
    <label>Username</label>
    <input type="text" name="username" autocomplete="off">
    <label>Password</label>
    <input type="password" name="password">
    <button type="submit">Sign In</button>
  </form>
  <?= $message ?>
</div>
</body>
</html>
