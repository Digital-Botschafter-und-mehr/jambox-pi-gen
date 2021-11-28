#!/bin/bash
JACK_APP=jamulus
sudo systemctl set-environment JACK_APP=jamulus

if [ -f ~/.config/Jamulus/jamulus_start.conf ]; then
  source ~/.config/Jamulus/jamulus_start.conf
fi

# check if a MIDI device is connected
MIDI_DEVICE_COUNT=`amidi -l | grep hw: | wc -l`
if [[ "$MIDI_DEVICE_COUNT" == "0" ]]; then
  # if no MIDI devices, don't pass any string to Jamulus even if one was configured
  unset JAMULUS_CTRLMIDICH
  unset JAMULUS_MIDI_SCRIPT
else
  # If a MIDI device is connected, check for known MIDI controllers (currently only X-Touch Mini)
  MIDI_DEVICE=`amidi -l | grep "X-TOUCH MINI" | head -n1`
  if [[ -n "$MIDI_DEVICE" ]]; then
    JAMULUS_CTRLMIDICH="11;f1*8;p11*8;m19*8;s27*8"
    JAMULUS_MIDI_SCRIPT=/usr/local/bin/midi-jamulus-xtouchmini.py
  fi
  # If no match, check for additional known MIDI controllers here
  # 
  # if still no JAMULUS_MIDI_SCRIPT set, but JAMULUS_CTRLMIDICH is set, use a default script that connects jack midi to jamulus
  [[ -n "$JAMULUS_CTRLMIDICH" ]] && [[ -z "$JAMULUS_MIDI_SCRIPT" ]] && JAMULUS_MIDI_SCRIPT=/usr/local/bin/midi-jamulus-passthrough.py

  if [[ -n "$JAMULUS_CTRLMIDICH" ]]; then
    # we are using MIDI with jamulus.  Set a default MIDI script if none has been selected.
    [[ -z "$JAMULUS_MIDI_SCRIPT" ]] && JAMULUS_MIDI_SCRIPT=/usr/local/bin/midi-jamulus-passthrough.py
    # Jack will be forced to capture MIDI devices and send to jack.  Save the current state so we can set it back after Jamulus exits.
    JACK_MIDI_ARG_SAVE=`sudo systemctl show-environment | grep JACK_MIDI_ARG | head -n1`
    sudo systemctl set-environment JACK_MIDI_ARG="-X raw"
  fi
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
    echo "ALSA Device $DEVICE not available: PLAY_RESULT: $PLAY_RESULT, RECORD_RESULT: $RECORD_RESULT"
    sleep 5
  fi
done

[[ -n "$MASTER_LEVEL" ]] && amixer set Master $MASTER_LEVEL
[[ -n "$CAPTURE_LEVEL" ]] && amixer set Capture $CAPTURE_LEVEL

# if JAMULUS_SERVER is defined, check for connectivity
if [ -n "$JAMULUS_SERVER" ]; then
  if [[ "$JAMULUS_SERVER" == *:* ]]; then
    JAMULUS_PORT="${JAMULUS_SERVER##*:}"
  else
    JAMULUS_PORT=22124
  fi
  # Check that Jamulus server is reachable by sending a Jamulus UDP ping, and checking if server replies
  # This should work even if server is behind a NAT
  while [[ "`echo -n -e '\x00\x00\xea\x03\x00\x05\x00\xab\x2e\x04\x00\x00\x48\x9b' | nc -u -w 2 ${JAMULUS_SERVER%:*} ${JAMULUS_PORT} 2>/dev/null | wc -c`" == "0" ]]
  do
    echo "Jamulus Server ${JAMULUS_SERVER%:*} is not reachable on UDP port ${JAMULUS_PORT}, retrying in 15 seconds."
    sleep 15
  done
fi

sudo systemctl restart jack
sleep 5

# check that jack service is running
while [[ "`systemctl show -p SubState --value jack`"  != "running" ]]
do
  echo "jack SubState is: `systemctl show -p SubState --value jack`; restarting jack"
  sudo systemctl restart jack
  sleep 5
done

# Start aj-snapshot as a background process.
# this will make the alsa/jack connections specified in snapshot file $AJ_SNAPSHOT after Jamulus starts
if [[ -f ~/.config/aj-snapshot/$AJ_SNAPSHOT ]]; then
  echo "Starting aj-snapshot daemon"
  aj-snapshot --remove --daemon ~/.config/aj-snapshot/$AJ_SNAPSHOT &
  AJ_SNAPSHOT_PID=$!
  JACKARG="--nojackconnect"
fi

# Start midi script as a background process
# This script needs to wait for Jamulus to start, then connect its midi ports and start processing
if [[ -f "$JAMULUS_MIDI_SCRIPT" ]]; then
  echo "starting Jamulus MIDI script $JAMULUS_MIDI_SCRIPT"
  $JAMULUS_MIDI_SCRIPT &
  MIDI_SCRIPT_PID=$!
fi

# kill pulseaudio after Jamulus has started
/bin/bash -c "sleep 6; XDG_RUNTIME_DIR=/run/user/$(id -u pi) /usr/bin/pulseaudio --kill" &

# start Jamulus with --nojackconnect option if aj-snapshot is controlling the connections.
# Jamulus will create a Jack MIDI input port only if parameter $JAMULUS_CTRLMIDICH is non-empty
if [ -n "$JAMULUS_SERVER" ]; then
  if [[ -n "$JAMULUS_PRIORITY" ]]; then
    timeout ${JAMULUS_TIMEOUT:-120m} chrt --${JAMULUS_SCHED:-fifo} ${JAMULUS_PRIORITY:-70} jamulus $JACKARG -c $JAMULUS_SERVER --ctrlmidich "${JAMULUS_CTRLMIDICH}"
  else
    timeout ${JAMULUS_TIMEOUT:-120m} nice -n ${JAMULUS_NICEADJ:-0} jamulus $JACKARG -c $JAMULUS_SERVER --ctrlmidich "${JAMULUS_CTRLMIDICH}"
  fi
  RESULT=$?
  # shutdown if ended due to timeout
  [[ "$RESULT" != "0" ]] && sudo shutdown now
else
  if [[ -n "$JAMULUS_PRIORITY" ]]; then
    nice -n ${JAMULUS_NICEADJ:-0} chrt --${JAMULUS_SCHED:-rr} ${JAMULUS_PRIORITY} jamulus $JACKARG --ctrlmidich "${JAMULUS_CTRLMIDICH}"
  else
    nice -n ${JAMULUS_NICEADJ:-0} jamulus $JACKARG --ctrlmidich "${JAMULUS_CTRLMIDICH}"
  fi
fi

[[ -n "$AJ_SNAPSHOT_PID" ]] && kill $AJ_SNAPSHOT_PID   # kill aj-snapshot background process
[[ -n "$MIDI_SCRIPT_PID" ]] && kill $MIDI_SCRIPT_PID   # kill midiscript background process
sudo systemctl unset-environment JACK_APP
# restore systemd version of JACK_MIDI_ARG to previous state if set
if [[ -n "$JACK_MIDI_ARG_SAVE" ]]; then
  eval $JACK_MIDI_ARG_SAVE
  sudo systemctl set-environment JACK_MIDI_ARG="$JACK_MIDI_ARG"
else
  [[ -n "$JAMULUS_CTRLMIDICH" ]] && sudo systemctl unset-environment JACK_MIDI_ARG
fi
sudo systemctl restart jack
exit 0
