# idk
Idiotic Doodle Killer

A goofy attempt at replicating doodle.com in a single PHP file.

It's probably insecure. Use at your own risk.

## Explanation

To use, create a directory under where you've placed idk.php. Each
event requires its own directory. The directory name is then passed
via HTTP GET to idk.php as the ```ding``` variable.

Example:

```https://www.example.com/idk.php?ding=birthday```

For each directory, a file (conf) contains information about the
event.

Responses are stored as files in the event directory with the filename
set to the name of the responder. Default MAX_RESPONSES is 20.

When a user submits their response they will receive a confirmation
web page. Responses received with the same name overwrite the previous
response.

## Animals

All confirmations come with a unique animal string, which is also
stored in the response file. If a user changes their response they
will receive a new animal string. A user and coordinator can share the
animal string if a user forgets what name they entered.

Product testing has confirmed that users love animal strings!

## conf syntax

Lines beginning with # are comments.

Lines beginning with : are directives. Values for each directive are
placed on the lines following a directive.

### Available directives

#### : title

The title of the event.

#### : closing

The closing date of the event in YYY-MM-DD syntax. After this date
idk will no longer accept responses.

####  : choices

The available choices for the event.

#### : options

The options for each choice.

### Example conf file

```

: title
Bob's Birthday Party

: closing
2024-08-01

: choices
July 26, 19:00 -
July 27, 14:00 - 18:00
July 27, 18:00 - 22:00
July 28, 14:00 - 18:00
July 28, 18:00 - 22:00

August 2, 19:00 -
August 3, 14:00 - 18:00
August 3, 18:00 - 22:00
August 4, 14:00 - 18:00
August 4, 18:00 - 22:00

August 9, 19:00 -
August 10, 14:00 - 18:00
August 10, 18:00 - 22:00
August 11, 14:00 - 18:00
August 11, 18:00 - 22:00

: options
yes
yes-but-painful
I-might-be-late

```

## Results
To generate results do something like the following in the ding directory..
```ls|grep -v conf|xargs grep -h "::"|grep -v Animal|sort|uniq -c```
