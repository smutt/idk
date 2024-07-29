#!/bin/bash

# help set
# -x  Print commands and their arguments as they are executed.
# -e  Exit immediately if a command exits with a non-zero status.
# -o  option-name
#       Set the variable corresponding to option-name:
#         pipefail     the return value of a pipeline is the status of
#                      the last command to exit with a non-zero status,
#                      or zero if no command exited with a non-zero status
if [ -n "$VERBOSE" ] && [ "$VERBOSE" -gt 1 ]; then
	# verbose of 2 or higher, be very verbose
	set -x
fi
set -e
set -o pipefail

function abort() {
	echo "$@" >&2
	exit 1
}

function info-msg() {
	# can be silenced by "VERBOSE=-1"
	if [ -z "$VERBOSE" ] || [ "$VERBOSE" -ge 0 ]; then
		echo -e "\n$@" >&2
	fi
}

function debug-msg() {
	if [ -n "$VERBOSE" ] && [ "$VERBOSE" -gt 0 ]; then
		echo -e "$@" >&2
	fi
}

# ensure we have the utilities installed
for CMD in php curl xxd tr; do
	debug-msg "checking we have $CMD"
	if ! command -v $CMD >/dev/null 2>&1; then
		abort "no '$CMD' found in PATH"
	fi
done

function hex-encode() {
    echo -n "$1" | xxd -p | tr --delete '\n'
}

function hex-decode() {
    echo "$1" | xxd -r -p
}

function url-encode() {
	php -r 'echo urlencode($argv[1]);' "$1"
}

ASSSERTIONS=0

function check-file-contains() {
	FILE=$1
	SEARCH_FOR=$2
	debug-msg "searching for '$SEARCH_FOR' in $FILE"
	if ! grep -q "$SEARCH_FOR" $FILE; then
		abort "file '$FILE' does not contain '$SEARCH_FOR'"
	fi
	ASSSERTIONS=$(( 1 + $ASSSERTIONS ))
}

function check-http-get() {
	URL=$1
	FILE=$2
	EXPECTED=$3

	if [ -z "$EXPECTED" ]; then EXPECTED=200; fi

	debug-msg "fetching $OUT_FILE_1 from $URL, expecting HTTP $EXPECTED"

	HTTP_RESPONSE=$(curl \
			--silent \
			--write-out "%{http_code}" \
			--output "$FILE" \
			"$URL")
	if [ -z "$HTTP_RESPONSE" ] || [ "$HTTP_RESPONSE" != "$EXPECTED" ]; then
		abort "HTTP_RESPONSE $HTTP_RESPONSE != $EXPECTED"
	fi
	ASSSERTIONS=$(( 1 + $ASSSERTIONS ))
}

function free-ports() {
	# since we know we are using PHP,
	# we can find free ports the PHP way:
	php -r '$num_sockets = (isset($argv[1]) && (int)$argv[1] > 0)
			? (int)$argv[1] : 1;
		$sockets = [];
		for ($i = 0; $i < $num_sockets; ++$i) {
			$socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
			socket_bind($socket, "0.0.0.0", 0);
			$sockets[] = $socket;
		}
		for ($i = 0; $i < $num_sockets; ++$i) {
			$socket = $sockets[$i];
			socket_getsockname($socket, $address, $port);
			print "$port\n";
			socket_close($socket);
		}' "$1"
}

TEST_DIR=test-output
rm -rf $TEST_DIR
if [ -n "$VERBOSE" ] && [ "$VERBOSE" -gt 0 ]; then
	MAYBE_VERBOSE="-v"
else
	MAYBE_VERBOSE=""
fi
mkdir $MAYBE_VERBOSE -p $TEST_DIR

BEGIN_MARKER=$TEST_DIR/run-timestamp
date --utc +%Y-%m-%dT%H:%M:%SZ > $BEGIN_MARKER

SERVER_LOG=$TEST_DIR/server.log
PORT_HTTP=$(free-ports)
if [ -n "$VERBOSE" ] && [ "$VERBOSE" -gt 0 ]; then
	php -S "localhost:$PORT_HTTP" ./idk.php 2>&1 | tee $SERVER_LOG &
else
	php -S "localhost:$PORT_HTTP" ./idk.php >$SERVER_LOG 2>&1 &
fi
PID_HTTP_SERVER=$!

function cleanup() {
	debug-msg "shutting down ikd.php $PID_HTTP_SERVER"
	kill $PID_HTTP_SERVER
}
trap cleanup EXIT

debug-msg "launched idk.php server on port $PORT_HTTP (PID=$PID_HTTP_SERVER)"
sleep 0.1

info-msg "checking for error on missing parameter"
OUT_FILE_BAD1="$TEST_DIR/no-ding.html"
check-http-get "localhost:$PORT_HTTP" $OUT_FILE_BAD1 500

info-msg "checking for error on bogus ding"
OUT_FILE_BAD2="$TEST_DIR/bogus-ding.html"
check-http-get "localhost:$PORT_HTTP/?ding=bogus" $OUT_FILE_BAD2 500

info-msg "make a valid request"
OUT_FILE_1="$TEST_DIR/ding-1.html"
check-http-get "localhost:$PORT_HTTP/?ding=example-event" $OUT_FILE_1 200

info-msg "basic sanity check that we have an HTML file"
check-file-contains $OUT_FILE_1 '<!DOCTYPE HTML'

info-msg "check the form exists"
check-file-contains $OUT_FILE_1 \
	'<form action="idk.php" method="post">'

info-msg "check the submit button exits"
check-file-contains $OUT_FILE_1 \
	'<input type="submit" id="sendit" value="Send it!" name="sendit">'

info-msg "check the 'ding' exists"
check-file-contains $OUT_FILE_1 \
	'<input type="hidden" name="ding" value="example-event">'

info-msg "check the name field exists"
check-file-contains $OUT_FILE_1 \
	'<input type="text" id="nombre" name="nombre"></td>'

info-msg "check some expected selections exist"
check-file-contains $OUT_FILE_1 'January 2, 14:00 - 18:00'
check-file-contains $OUT_FILE_1 'January 3, 18:00 - 22:00'
check-file-contains $OUT_FILE_1 'January 4, 18:00 - 22:00'

function check-id-for-selection() {
	FILE=$1
	SELECTOR=$2
	ERRORS=0

	debug-msg "FILE='$FILE'"
	debug-msg "SELECTOR='$SELECTOR'"
	ID=$( grep --after-context=2 "$SELECTOR" "$FILE" \
		| grep 'id=' \
		| sed --quiet 's/.*id="\([^"]*\)".*/\1/p' \
		| head -n1
	)
	debug-msg "ID='$ID'"

	ENCODE_SELECTOR=$(hex-encode "$SELECTOR")
	debug-msg "ENCODE_SELECTOR=$ENCODE_SELECTOR"

	if [ "$ID" != "$ENCODE_SELECTOR" ]; then
		echo "expected id='$ENCODE_SELECTOR'" >&2
		echo "  but is id='$ID'" >&2
		ERRORS=$(( 1 + $ERRORS ))
	fi

	DECODE_ID=$(hex-decode "$ID")
	debug-msg "DECODE_ID=$DECODE_ID"

	if [ "$DECODE_ID" != "$SELECTOR" ]; then
		echo "expected decode='$SELECTOR'" >&2
		echo "  but is decode='$DECODE_ID'" >&2
		ERRORS=$(( 1 + $ERRORS ))
	fi

	if [ $ERRORS -ne 0 ]; then
		exit 1
	fi
}

debug-msg "by verifying that we can encode and decode the selectors\n" \
	 " we can avoid having to parse HTML to create a POST"
check-id-for-selection $OUT_FILE_1 'January 2, 14:00 - 18:00'
check-id-for-selection $OUT_FILE_1 'January 3, 18:00 - 22:00'
check-id-for-selection $OUT_FILE_1 'January 4, 18:00 - 22:00'

function select-option() {
	NAME=$1
	VALUE=$2
	echo $(hex-encode "$NAME")=$(url-encode "$VALUE")
}

info-msg "submit a valid post"
DISK_FILE=example-event/alice
OUT_FILE_2=$TEST_DIR/post-response-1.html
HTTP_RESPONSE=$(curl \
	--request POST \
	--silent \
	--write-out "%{http_code}" \
	--data 'ding=example-event' \
	--data 'nombre=alice' \
	--data "$(select-option 'January 2, 14:00 - 18:00' 'yes')" \
	--data "$(select-option 'January 3, 18:00 - 22:00' 'yes-but-hard')" \
	--data "$(select-option 'January 4, 18:00 - 22:00' 'yes')" \
	--location \
	--output $OUT_FILE_2 \
	localhost:$PORT_HTTP/idk.php
)

if [ -z "$HTTP_RESPONSE" ] || [ "$HTTP_RESPONSE" != "200" ]; then
	abort "HTTP_RESPONSE '$HTTP_RESPONSE' != 200"
fi

if [ ! -e "$DISK_FILE" ]; then
	abort "expected $DISK_FILE does not exist"
fi

if [ "$DISK_FILE" -ot $BEGIN_MARKER ]; then
	abort "$DISK_FILE is older than the BEGIN_MARKER file: $BEGIN_MARKER"
fi

info-msg "check the results"
for FILE in $OUT_FILE_2 $DISK_FILE; do
	check-file-contains $FILE 'Name :: alice'
	check-file-contains $FILE 'January 2, 14:00 - 18:00 :: yes'
	check-file-contains $FILE 'January 3, 18:00 - 22:00 :: yes-but-hard'
	check-file-contains $FILE 'January 4, 18:00 - 22:00 :: yes'
done

info-msg "check invalid post (bad characters in name)"
OUT_FILE_3=$TEST_DIR/post-response-bad-name.html
HTTP_RESPONSE=$(curl \
	--request POST \
	--silent \
	--write-out "%{http_code}" \
	--data 'ding=example-event' \
	--data "nombre=$(url-encode 'Bogus Bob; -- drop tables')" \
	--data "$(select-option 'January 2, 14:00 - 18:00' 'yes-but-hard')" \
	--data "$(select-option 'January 3, 18:00 - 22:00' 'yes')" \
	--location \
	--output $OUT_FILE_3 \
	localhost:$PORT_HTTP/idk.php
)
if [ -z "$HTTP_RESPONSE" ] || [ "$HTTP_RESPONSE" != "500" ]; then
	abort "HTTP_RESPONSE '$HTTP_RESPONSE' != 500"
else
	ASSSERTIONS=$(( 1 + $ASSSERTIONS ))
fi

info-msg "SUCCESS $0 ($ASSSERTIONS assertions performed)"
