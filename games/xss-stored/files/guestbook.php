<?php
// NovaTech Employee Guestbook
// BUG: message content is echoed directly to the page without HTML encoding.
// Any <script> tag posted as a message will execute in every visitor's browser.

$file = '/var/www/data/messages.json';
$messages = json_decode(@file_get_contents($file) ?: '[]', true) ?? [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name    = htmlspecialchars($_POST['name']    ?? 'Anonymous', ENT_QUOTES, 'UTF-8');
    $message = $_POST['message'] ?? '';
    if ($message !== '') {
        $messages[] = ['name' => $name, 'message' => $message, 'time' => date('H:i')];
        file_put_contents($file, json_encode($messages));
    }
    header('Location: /guestbook.php');
    exit;
}
?><!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NovaTech Guestbook</title>
  <style>
    body { font-family: sans-serif; max-width: 640px; margin: 40px auto; padding: 0 20px; }
    .msg { border: 1px solid #ccc; padding: 10px; margin: 8px 0; border-radius: 4px; }
    .meta { color: #666; font-size: 0.85em; }
  </style>
</head>
<body>
<h1>NovaTech Employee Guestbook</h1>
<p>Leave a message for the team. All posts are reviewed by an admin bot.</p>

<form method="POST">
  <label>Your name: <input name="name" type="text" size="30"></label><br><br>
  <label>Message:<br>
    <textarea name="message" rows="4" cols="45" placeholder="Write your message here..."></textarea>
  </label><br><br>
  <input type="submit" value="Post Message">
</form>

<hr>
<h2>Recent Messages</h2>
<?php if (empty($messages)): ?>
  <p><em>No messages yet. Be the first to post!</em></p>
<?php endif; ?>
<?php foreach ($messages as $m): ?>
<div class="msg">
  <span class="meta"><strong><?= $m['name'] ?></strong> at <?= htmlspecialchars($m['time'], ENT_QUOTES, 'UTF-8') ?></span><br>
  <?= $m['message'] ?>
</div>
<?php endforeach; ?>
</body>
</html>
