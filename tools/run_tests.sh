#!/bin/bash
# Runs test suites in a real window, with their results in a console window
# beside it (and in this terminal too).
#   tools/run_tests.sh                 every suite except check_hiding
#   tools/run_tests.sh stage1 boxes    just these (names without check_)
# A suite that hits a SCRIPT ERROR, or runs past TIMEOUT seconds, is stopped
# so the run moves on instead of hanging.

cd "$(dirname "$0")/.."
G="/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"
MINTTY="/c/Program Files/Git/usr/bin/mintty.exe"
TIMEOUT=240
# Seconds to let a suite print anything else after a script error.
ERROR_GRACE=2

if [ $# -eq 0 ]; then
	set -- stage1 stage2 stage3 stage4 floor_clutter smoothness menus grab_point \
		impacts catch furniture beam_look beam_sound room lamp tutorial boxes \
		hiding_places bump demo
fi

# Game on the left, results on the right.
GAME_RES=1280x720
GAME_POS=40,120
CONSOLE_POS=1360,120
CONSOLE_SIZE=100,44

out=$(mktemp -d)
log="$out/results.log"
: > "$log"
# -h always keeps the results window open after the run ends.
"$MINTTY" -t "Test results" -p "$CONSOLE_POS" -s "$CONSOLE_SIZE" -h always \
	-o FontHeight=13 -o Font="Consolas" -o BackgroundColour=24,24,28 \
	-e tail -n +1 -f --pid=$$ "$log" &

# Windows process id of the Godot run whose command line holds $1.
winpid() {
	powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"CommandLine like '%$1%' and Name like 'Godot%'\").ProcessId" | tr -d '\r'
}
running() { tasklist //FI "PID eq $1" //NH 2>/dev/null | grep -q Godot; }

say() { printf '%s\n' "$1" | tee -a "$log"; }

# Green PASS, red FAIL and SCRIPT ERROR, bold RESULT.
colour() {
	sed -u -e $'s/^PASS/\e[32mPASS\e[0m/' -e $'s/^FAIL/\e[1;31mFAIL\e[0m/' \
		-e $'s/^\\(SCRIPT ERROR.*\\)/\e[1;31m\\1\e[0m/' -e $'s/^\\(RESULT.*\\)/\e[1m\\1\e[0m/'
}

declare -a summary
for t in "$@"; do
	raw="$out/$t.raw"
	: > "$raw"
	say ""
	say $'\e[1;36m=== '"$t"$' ===\e[0m'
	# Git Bash's kill can't reach the real Godot process, so the run is tagged
	# with a throwaway user arg and found by its Windows process id instead.
	tag="run_tests_$$_$t"
	"$G" --path . --resolution "$GAME_RES" --position "$GAME_POS" "res://tests/check_$t.tscn" -- "$tag" hands_off > "$raw" 2>&1 &
	# Git Bash's stand-in for the game lives as long as the game does, so the
	# reader stops (and the pipe drains) once the game has closed.
	tail -n +1 -f --pid=$! "$raw" | grep --line-buffered -E "^(PASS|FAIL|RESULT)|SCRIPT ERROR" | colour | tee -a "$log" &
	follower=$!
	pid=""
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		pid=$(winpid "$tag")
		[ -n "$pid" ] && break
		sleep 0.5
	done

	# A script error leaves the test's coroutine dead and the window open,
	# so watch for one (and for a stall) and close the game ourselves.
	start=$SECONDS
	stopped=""
	while [ -n "$pid" ] && running "$pid"; do
		if grep -q "SCRIPT ERROR" "$raw"; then
			sleep $ERROR_GRACE
			stopped="script error"
			break
		fi
		if (( SECONDS - start > TIMEOUT )); then
			stopped="timed out after ${TIMEOUT}s"
			break
		fi
		sleep 0.5
	done
	if [ -n "$stopped" ]; then
		taskkill //F //T //PID "$pid" > /dev/null 2>&1
	fi
	wait $follower 2>/dev/null

	if [ -n "$stopped" ]; then
		say $'\e[1;31m!! stopped: '"$stopped"$'\e[0m'
		summary+=("$t: stopped ($stopped)")
	elif grep -q "RESULT: ALL PASS" "$raw"; then
		summary+=("$t: pass")
	else
		summary+=("$t: $(grep -c '^FAIL' "$raw") failed")
	fi
	rm -f "$raw"
done

say ""
say $'\e[1;36m=== summary ===\e[0m'
for line in "${summary[@]}"; do
	case "$line" in
		*": pass") say $'\e[32m'"$line"$'\e[0m' ;;
		*) say $'\e[1;31m'"$line"$'\e[0m' ;;
	esac
done
