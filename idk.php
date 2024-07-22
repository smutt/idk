<?php
// Idiotic Doodle Killer

error_reporting(E_ALL);

function bug_outs($txt){
  error_log($txt);
  http_response_code(500);
  exit(1);
}

// Takes the contents of the conf file
// Returns assoc array
function parse_conf($txt){
  if( $txt == false){
    bug_out("Bad conf parse dude");
  }

  $rv = array();
  foreach(explode(PHP_EOL, $txt) as $line){
    $line = trim($line);
    if( strlen($line) == 0){
      continue;
    }
    if( strpos($line, ":") === 0){
      $idx = trim($line, ": ");
      $rv[$idx] = array();
      continue;
    }
    array_push($rv[$idx], $line);
  }
  return $rv;
}

// Deal with it
function process_post($data){
  var_dump($data);
}

if(isset($_POST['name'])){
  process_post($_POST['name']);
  print "\nThanks for your input!";
  exit(0);
}


if( !isset($_GET['ding'])){
  bug_out("No ding");
}
$ding = $_GET['ding'];

if( !is_dir($ding)){
  bug_out("Bad ding dir");
}

if( !is_readable($ding . "/conf")){
  bug_out("No conf in ding dir");
}
?>

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
<head>
<title><?php print($ding . " Selection"); ?></title>
</head>
<body>

<?php
$conf = parse_conf(trim(file_get_contents($ding . "/conf")));

print "\n<form action=\"idk.php\" method=\"post\">";
print "\n<table>";
print $conf['title'][0];
print "<tr><td>Name (ASCII only, max 30 characters)</td><td> <input type=\"text\" id=\"name\" name=\"name\"></td></tr>";
foreach($conf['choices'] as $choice){
  print "\n<tr><td>";
  print "\n<label for=\"" . $choice . "\">" . $choice . "</label></td>";
  print "\n<td><select id=\"" . $choice . "\" name=\"" . $choice . "\">";

  $first = true;
  foreach($conf['options'] as $option){
    if($first){
      $first = false;
      print "\n<option value=\"" . $option . "\" selected>" . $option . "</option>";
    }else{
      print "\n<option value=\"" . $option . "\">" . $option . "</option>";
    }
  }
  print "\n</select></td></tr>";
}

?>
<tr colspan="2"><td><input type="submit" id="sendit" value="Send it!" name="sendit"></td></tr>
</table>
</form>
</body>
