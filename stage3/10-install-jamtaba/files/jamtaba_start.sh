#!/bin/bash
# jack needs longer PERIOD for JamTaba.  Set JACK_APP for jack to inspect.
JACK_APP=jamtaba
sudo systemctl set-environment JACK_APP=jamtaba

# reset JamTaba window position & size to defaults
if [ -f ~/.config/jamtaba_start.conf ]; then
  source ~/.config/jamtaba_start.conf
  [[ -n "$INIT_POSITION" ]] && sed -i "s/^pos=.*/pos=${INIT_POSITION}/" ~/.config/JamTaba\ 2.conf
  [[ -n "$INIT_SIZE" ]] && sed -i "s/^size=.*/size=${INIT_SIZE}/" ~/.config/JamTaba\ 2.conf
fi

# check if a MIDI device is connected
MIDI_DEVICE_COUNT=`amidi -l | grep hw: | wc -l`
if [[ "$MIDI_DEVICE_COUNT" != "0" ]]; then
  # Jack will be forced to not capture MIDI devices so they can connect to JamTaba with ALSA.  Save the current state so we can set it back after JamTaba exits.
  JACK_MIDI_ARG_SAVE=`sudo systemctl show-environment | grep JACK_MIDI_ARG | head -n1`
  sudo systemctl unset-environment JACK_MIDI_ARG
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

sudo systemctl restart jack
sleep 5

# check that jack service is running
while [[ "`systemctl show -p SubState --value jack`"  != "running" ]]
do
  echo "jack SubState is: `systemctl show -p SubState --value jack`; restarting jack"
  sudo systemctl restart jack
  sleep 5
done

if [[ -n "$JAMTABA_PRIORITY" ]]; then
  chrt --${JAMTABA_SCHED:-rr} ${JAMTABA_PRIORITY} Jamtaba2 &
else
  nice -n ${JAMTABA_NICEADJ:-0} Jamtaba2 &
fi
JAMTABA_PID=$!

sleep 10
echo JAMTABA_PID: $JAMTABA_PID
PACTL_SINK_MODULE=`sudo pactl load-module module-jack-sink client_name=JamTaba_OUTput`
echo PACTL_SINK_MODULE: $PACTL_SINK_MODULE
PACTL_SOURCE_MODULE=`sudo pactl load-module module-jack-source client_name=JamTaba_INput`
echo PACTL_SOURCE_MODULE: $PACTL_SOURCE_MODULE

wait $JAMTABA_PID
sudo pactl unload-module $PACTL_SINK_MODULE
sudo pactl unload-module $PACTL_SOURCE_MODULE

sudo systemctl unset-environment JACK_APP
# restore systemd version of JACK_MIDI_ARG to previous state if set
if [[ -n "$JACK_MIDI_ARG_SAVE" ]]; then
  eval $JACK_MIDI_ARG_SAVE
  sudo systemctl set-environment JACK_MIDI_ARG="$JACK_MIDI_ARG"
fi
sudo systemctl restart jack
exit 0
