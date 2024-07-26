<?php
// Idiotic Doodle Killer (IDK)
// Replacement for doodle.com in a single PHP file

$MAX_RESPONSES = 20; // Maximum number of responses we'll accept
$MIN_CHARS_NAME = 3; // Minimum number of characters allowed in name
$MAX_CHARS_NAME = 10; // Maximum number of characters allowed in name
$BAD_HOMBRES = array("conf"); // Disallowed nombres
$ANIMALS_FILE = "animals_sha256.txt"; // Animals and their SHA256 hash sorted by hash ascending

error_reporting(E_ALL);

function bug_out($txt){
  error_log("idk:" . $txt);
  http_response_code(500);
  exit(1);
}

// Takes a string and an array of extra characters that are permitted
// Returns true if permitted, false if not
function check_str($txt, $extras){
  for($ii = 0, $len = strlen($txt); $ii<$len; $ii++){
    $oo = ord($txt[$ii]);
    if( !($oo>47 && $oo<58)) { // numbers
      if( !($oo>64 && $oo<91)){ // upper letters
        if( !($oo>96 && $oo<123)){ // lower letters
          $extra_found = false;
          foreach($extras as $ee){
            if($oo == ord($ee)){
              $extra_found = true;
            }
          }
          if( !$extra_found){
            return false;
          }
        }
      }
    }
  }
  return true;
}

// Takes passed ding value
// Returns true if good otherwise false
function check_ding($ding){
  if( !check_str($ding, array("_", "-"))){
    error_log("Illegal char in ding");
    return false;
  }
  if( !is_dir($ding)){
    error_log("ding not a dir");
    return false;
  }
  if( !is_readable($ding . "/conf")){
    error_log("ding/conf not readable");
    return false;
  }
  if( !is_writable($ding)){
    error_log("ding dir not writable");
    return false;
  }
  return true;
}

// Check passed nombre
// Returns true if good otherwise false
function check_nombre($txt){
  if( !check_str($txt, array("_", "-", " "))){
    return false;
  }
  if( in_array($txt, $GLOBALS['BAD_HOMBRES'])){
    return false;
  }
  if(strlen($txt) < $GLOBALS['MIN_CHARS_NAME']){
    return false;
  }
  if(strlen($txt) > $GLOBALS['MAX_CHARS_NAME']){
    return false;
  }
  return true;
}

// Takes the contents of the conf file
// Returns assoc array
function parse_conf($txt){
  $rv = array();
  foreach(explode(PHP_EOL, $txt) as $line){
    $line = trim($line);
    if(strlen($line) == 0){
      continue;
    }
    if(strpos($line, "#") === 0){
      continue;
    }
    if(strpos($line, ":") === 0){
      $idx = trim($line, ": ");
      $rv[$idx] = array();
      continue;
    }
    array_push($rv[$idx], $line);
  }
  return $rv;
}

// Takes a string
// Return animal string associated with next ascending hash
function match_animal($txt){
  $animals = array(hash("sha256", $txt, false) => "");
  foreach(file($GLOBALS['ANIMALS_FILE']) as $line){
    list($hash, $critter) = explode(" ", $line);
    $animals[$hash] = $critter;
  }

  ksort($animals);
  reset($animals);
  while(next($animals) !== false){
    if(current($animals) == ""){
      if(next($animals) != null){
        return current($animals);
      }else{
        return array_shift($animals);
      }
    }
  }
}

// Deal with POST data
function process_post($data){
  if( !isset($_POST['ding'])){
    bug_out("No ding in POST");
  }
  if(! check_ding($_POST['ding'])){
    bug_out("bad ding in POST");
  }
  $ding = $_POST['ding'];
  $conf = parse_conf(trim(file_get_contents($ding . "/conf")));

  $closing = explode("-", $conf['closing'][0]);
  if(time() > mktime(0, 0, 0, $closing[1], $closing[2], $closing[0])){
    bug_out("Late response attempt in POST");
  }

  if( !check_nombre($_POST['nombre'])){
    print("Bad name");
    bug_out("Bad nombre in POST");
  }else{
    $nombre = $_POST['nombre'];
  }

  $fileput = "Name :: " . $nombre . "\n\n";
  foreach($_POST as $key => $val){
    if($key == 'ding' || $key == 'nombre' || $key == 'sendit'){
      continue;
    }
    $choice = hex2bin($key);
    if( !in_array($choice, $conf['choices'], true)){
      bug_out("Bogus choice given in POST");
    }else{
      $fileput .= $choice . " :: " . $val . "\n";
    }
  }
  $fileput .= "Animal :: " . match_animal($fileput) . "\n";

  // Write fileput to file
  // Overwrite existing file if same nombre
  $files = scandir($ding);
  if(in_array($nombre, $files)){
    file_put_contents($ding . "/" . $nombre, $fileput, LOCK_EX);
  }else{
    if(count($files) - 2 - count($GLOBALS['BAD_HOMBRES']) < $GLOBALS['MAX_RESPONSES']){
      file_put_contents($ding . "/" . $nombre, $fileput, LOCK_EX);
    }else{
      print("Max responses received");
      bug_out("Max responses received");
    }
  }

  // Print webput to user
  $webput = "<html><head></head><body>";
  foreach(explode("\n", $fileput) as $line){
    $webput .= "\n" . $line . "<br/>";
  }
  $webput .= "\n</body><html>";
  print($webput);
}

/////////////////////
// BEGIN EXECUTION //
/////////////////////
if(isset($_POST['nombre'])){
  if(strlen($_POST['nombre']) > 0){
    process_post($_POST);
    exit(0);
  }else{
    $_GET['ding'] = $_POST['ding']; // disgusting hack :)
  }
}

// Check ding
if( !isset($_GET['ding'])){
  bug_out("No ding");
}
if(! check_ding($_GET['ding'])){
  bug_out("bad ding");
}
$ding = $_GET['ding'];

if( !($cf = file_get_contents($ding . "/conf"))){
  bug_out("Unreadable conf file " . $ding);
}
$conf = parse_conf(trim($cf));

$closing = explode("-", $conf['closing'][0]);
if(time() > mktime(0, 0, 0, $closing[1], $closing[2], $closing[0])){
  print("Responses are closed");
  bug_out("Late response attempt");
}
?>

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
<head>
<title><?php print($ding . " Selection"); ?></title>
</head>
<body>

<?php
print "\n<form action=\"idk.php\" method=\"post\">";
print "\n <input type=\"hidden\" name=\"ding\" value=\"" . $ding . "\">";
print $conf['title'][0];
print " (Repeat same name to overwrite previous)";
print "\n<table>";
print "<tr><td>Name </td><td> <input type=\"text\" id=\"nombre\" name=\"nombre\"></td>";
print "<td>(ASCII letters and numbers only, min " . $MIN_CHARS_NAME . " max " . $MAX_CHARS_NAME . ")</td></tr>";

print "\n<tr><td></td>";
foreach($conf['options'] as $option){
  print "<td>" . $option . "</td>";
}
print "</tr>";

foreach($conf['choices'] as $choice){
  print "\n\n<tr><td>" . $choice . "</td>";
  $hex_choice = bin2hex($choice);

  foreach($conf['options'] as $option){
    print "\n<td><input type=\"radio\" id=\"" . $hex_choice . "\" name=\"" . $hex_choice . "\" value=\"" . $option . "\"></td>";
   }
  print "\n</tr>";
}

?>
<tr>
  <td></td>
  <td><input type="reset" value="Reset it!"></td>
  <td><input type="submit" id="sendit" value="Send it!" name="sendit"></td>
  </tr>
</table>
</form>
</body>
