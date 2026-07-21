<?php
// Athenaeum Digital Library — Book Catalogue Search
// INTENTIONALLY VULNERABLE: the search term is concatenated directly into a
// SQL query. This exposes a UNION-based SQL injection: an attacker can append
// their own SELECT to pull data out of OTHER tables (e.g. the librarian_notes
// table that holds the flag).
$db = new SQLite3('/var/www/db/library.db');
$db->enableExceptions(true);

$q = isset($_GET['q']) ? $_GET['q'] : '';
$rows = [];
$error = '';

if (isset($_GET['q'])) {
    try {
        // VULNERABLE: $q is not sanitised or parameterised.
        // The result set has exactly two columns: title, author.
        $sql = "SELECT title, author FROM books WHERE title LIKE '%$q%'";
        $res = $db->query($sql);
        while ($row = $res->fetchArray(SQLITE3_ASSOC)) {
            $rows[] = $row;
        }
    } catch (Exception $e) {
        $error = $e->getMessage();
    }
}
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Athenaeum Digital Library — Catalogue</title>
<style>
  body  { font-family: Georgia, serif; background: #faf7f0; color: #2b2b2b;
          max-width: 720px; margin: 40px auto; padding: 0 20px; }
  h1    { color: #5c3a21; margin-bottom: 4px; }
  .sub  { color: #806045; margin-top: 0; }
  form  { margin: 24px 0; }
  input[type=text] { padding: 8px; width: 320px; border: 1px solid #cbb79a; border-radius: 4px; }
  button { padding: 8px 16px; background: #5c3a21; color: #fff; border: none;
           border-radius: 4px; cursor: pointer; }
  table { width: 100%; border-collapse: collapse; margin-top: 16px; }
  th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #e3dcc9; }
  th { color: #5c3a21; }
  .err { color: #8b0000; background: #fdecea; padding: 10px; border-radius: 4px;
         word-break: break-all; }
  .empty { color: #806045; font-style: italic; }
</style>
</head>
<body>
<h1>Athenaeum Digital Library</h1>
<p class="sub">Search our public catalogue of over 40,000 titles.</p>

<form method="GET" action="">
  <input type="text" name="q" value="<?= htmlspecialchars($q, ENT_QUOTES, 'UTF-8') ?>" placeholder="Search by title...">
  <button type="submit">Search</button>
</form>

<?php if ($error !== ''): ?>
  <p class="err">Database error: <?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></p>
<?php endif; ?>

<?php if (isset($_GET['q']) && $error === ''): ?>
  <table>
    <tr><th>Title</th><th>Author</th></tr>
    <?php if (empty($rows)): ?>
      <tr><td colspan="2" class="empty">No titles matched your search.</td></tr>
    <?php endif; ?>
    <?php foreach ($rows as $r): ?>
      <tr>
        <td><?= htmlspecialchars($r['title'], ENT_QUOTES, 'UTF-8') ?></td>
        <td><?= htmlspecialchars($r['author'], ENT_QUOTES, 'UTF-8') ?></td>
      </tr>
    <?php endforeach; ?>
  </table>
<?php endif; ?>
</body>
</html>
