#!/bin/bash
# LORD door wrapper for Mystic BBS + dosemu2
# Called by Mystic as: /mystic/doors/lord/lord.sh %N
# %N = node number (1-5)
#
# Architecture: dosemu2 + virtual COM1 (deadbeatz/mystic_a45 pattern)
# $_com1 = "virtual" bridges DOS COM1 to dosemu's controlling PTY.
# Door I/O goes through COM1 → PTY → Mystic → user.
# Video output is suppressed (1>/dev/null) so no boot noise is visible.

NODE="${1:-1}"
DOORDIR="/mystic/doors/lord"
CDIR="$DOORDIR/C"
MYSTIC_TEMP="/mystic/temp${NODE}"
DROPFILE="$MYSTIC_TEMP/DOOR.SYS"
LOCALDIR="/tmp/dosemu-node${NODE}"
LOGFILE="/tmp/lord-node${NODE}-$(date +%s).log"

echo "[lord.sh] start node=$NODE dropfile=$DROPFILE" >> "$LOGFILE"

# --- Verify drop file ---
if [ ! -f "$DROPFILE" ]; then
    echo "ERROR: No DOOR.SYS found at $DROPFILE" | tee -a "$LOGFILE"
    sleep 3
    exit 1
fi

# --- Copy drop file to per-node dir C:\NODEx\ (BBSDROP in NODEx.DAT) ---
# Fix DOOR.SYS for LORD compatibility:
# 1. Keep COM1: (door uses COM1 via virtual serial)
# 2. Fill blank lines (Mystic leaves phone/password empty)
# 3. Cap seconds remaining (line 18) to 32000 — LORD uses 16-bit signed
#    integers, so values > 32767 wrap negative = "out of time"
NODEDIR="$CDIR/NODE${NODE}"
mkdir -p "$NODEDIR"
awk 'NR==18 && $0+0 > 32000 { printf "32000\r\n"; next }
     NR==19 && $0+0 > 500   { printf "500\r\n"; next }
     /^$/ { printf "NONE\r\n"; next }
     { gsub(/\r$/,""); printf "%s\r\n", $0 }' "$DROPFILE" > "$NODEDIR/DOOR.SYS"
echo "[lord.sh] drop file copied to NODE${NODE}" >> "$LOGFILE"

# --- Generate per-call random batch file with CRLF line endings ---
RAND=$(tr -dc a-f0-9 2>/dev/null </dev/urandom | head -c 4)
BATFILE="RUN${RAND}.BAT"
BATPATH="$NODEDIR/$BATFILE"
printf "C:\r\nCD \\LORD\r\nCALL START.BAT %s\r\nEXITEMU\r\n" "$NODE" > "$BATPATH"
echo "[lord.sh] batch file: $BATFILE" >> "$LOGFILE"

# --- Per-node dosemu2 local directory and config ---
mkdir -p "$LOCALDIR"
cat > "$LOCALDIR/dosemurc" << DOSEMURC
\$_cpu_vm = "emulated"
\$_cpu_vm_dpmi = "emulated"
\$_com1 = "virtual"
\$_sound = (off)
\$_speaker = "off"
\$_layout = "us"
\$_rawkeyboard = (0)
\$_hdimage = "$CDIR +1"
DOSEMURC

echo "[lord.sh] dosemurc written" >> "$LOGFILE"

# --- Terminal setup ---
stty cols 80 rows 25 2>/dev/null || true
export TERM="xterm"
export HOME="/home/tsali"

# --- Launch dosemu2 with COM1 virtual, video to /dev/null ---
dosemu \
    --Flocal_dir "$LOCALDIR" \
    -E "C:\\NODE${NODE}\\$BATFILE" \
    -o "$LOGFILE" \
    1>/dev/null \
    2>>"$LOGFILE"

DOSEMU_EXIT=$?
echo "[lord.sh] dosemu2 exited: $DOSEMU_EXIT" >> "$LOGFILE"

# --- Cleanup ---
rm -f "$BATPATH"
stty sane 2>/dev/null || true
