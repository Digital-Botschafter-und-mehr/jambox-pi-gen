#!/bin/bash
JACK_APP=hpsjam
sudo systemctl set-environment JACK_APP=hpsjam

if [ -f ~/.config/hpsjam_start.conf ]; then
  source ~/.config/hpsjam_start.conf
fi

# Audio interface is chosen in /etc/jackdrc.conf
# source it here to determine the device to use
if [ -f /etc/jackdrc.conf ]; then
  source /etc/jackdrc.conf
fi

echo ALSA Device: $DEVICE
ALSA_READY=no
until [[ $ALSA_READY == "yes" ]]; do
  aplay -L | grep -q "$DEVICE"
  PLAY_RESULT=$?
  arecord -L | grep -q "$DEVICE"
  RECORD_RESULT=$?
  if [[ "$PLAY_RESULT" == "0" ]] && [[ "$RECORD_RESULT" == "0" ]]; then
    ALSA_READY=yes
  else
    echo "ALSA Device $DEVICE is not available: PLAY_RESULT: $PLAY_RESULT, RECORD_RESULT: $RECORD_RESULT"
    sleep 5
  fi
done

# if HPSJAM_SERVER is defined, check for connectivity
if [ -n "$HPSJAM_SERVER" ]; then
  if [[ "$HPSJAM_SERVER" == *:* ]]; then
    HPSJAM_PORT="${HPSJAM_SERVER##*:}"
  else
    HPSJAM_PORT=22124
  fi
  # Check that HpsJam server is reachable by sending an HpsJam UDP ping, and checking if server replies
  # This should work even if server is behind a NAT
  PING='\x00\x13\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  PING+='\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  PING+='\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  PING+='\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  PING+='\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x41\x00'
  PING+='\x00\x00\x00\xeb\x0d\x00\x00\x00\x00\x00\x00\x00\x00'
  while [[ "`echo -n -e ${PING} | nc -u -w 2 ${HPSJAM_SERVER%:*} ${HPSJAM_PORT} 2>/dev/null | wc -c`" == "0" ]]
  do
    echo "HpsJam Server ${HPSJAM_SERVER%:*} is not reachable on UDP port ${HPSJAM_PORT}, retrying in 15 seconds."
    sleep 15
  done
fi

[[ -n "$MASTER_LEVEL" ]] && amixer set Master $MASTER_LEVEL
[[ -n "$CAPTURE_LEVEL" ]] && amixer set Capture $CAPTURE_LEVEL

sudo systemctl restart jack
sleep 5

# check that jack service is running
while [[ "`systemctl show -p SubState --value jack`"  != "running" ]]
do
  echo "jack SubState is: `systemctl show -p SubState --value jack`; restarting jack"
  sudo systemctl restart jack
  sleep 5
done

# Start aj-snapshot as a background process if JammerNetzClient had $AJ_SNAPSHOT set
# Default is unset (HpsJam makes alsa-jack connections).
# If set, this will make the alsa/jack connections specified in snapshot file $AJ_SNAPSHOT after HpsJam starts
if [[ -f ~/.config/aj-snapshot/$AJ_SNAPSHOT ]]; then
  echo "Starting aj-snapshot daemon"
  aj-snapshot --remove --daemon ~/.config/aj-snapshot/$AJ_SNAPSHOT &
  AJ_SNAPSHOT_PID=$!
  JACKARG="--jacknoconnect"
fi

# start HpsJam with --nojackconnect option if aj-snapshot is controlling the connections.
if [ -n "$HPSJAM_SERVER" ]; then
  if [[ -n "$HPSJAM_PRIORITY" ]]; then
    timeout ${HPSJAM_TIMEOUT:-120m} chrt --${HPSJAM_SCHED:-fifo} ${HPSJAM_PRIORITY:-70} HpsJam $JACKARG --connect $HPSJAM_SERVER
  else
    timeout ${HPSJAM_TIMEOUT:-120m} nice -n ${HPSJAM_NICEADJ:-0} HpsJam $JACKARG --connect $HPSJAM_SERVER
  fi
  RESULT=$?
  # shutdown if ended due to timeout
  [[ "$RESULT" != "0" ]] && sudo shutdown now
else
  if [[ -n "$HPSJAM_PRIORITY" ]]; then
    chrt --${HPSJAM_SCHED:-rr} ${HPSJAM_PRIORITY} HpsJam $JACKARG
  else
    nice -n ${HPSJAM_NICEADJ:-0} HpsJam $JACKARG
  fi
fi

[[ -n "$AJ_SNAPSHOT_PID" ]] && kill $AJ_SNAPSHOT_PID   # kill aj-snapshot background process
sudo systemctl unset-environment JACK_APP
sudo systemctl restart jack
exit 0
