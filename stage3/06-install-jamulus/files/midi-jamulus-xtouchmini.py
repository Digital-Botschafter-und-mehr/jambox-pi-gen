#!/usr/bin/python3

#
# Midi routing layer between jack and jamulus
# For Behringer X-Touch Mini MIDI controller
#
#
# Converts momentary pushbuttons (which send midi note events) 
# to toggle pushbuttons (by remembering state),
# and sends LED on/off messages back to midi controller to show state.
# Converts the note events from controller buttons into control events for jamulus.
#
# requires package python3-mididings from jambox-project repo,
# also requires package python-alsaaudio
#   sudo apt install python3-mididings python3-alsaaudio

from mididings import *
from mididings.event import *
import alsaaudio
import time
import jack
import sys

#
# configure mididings with 1 input & 2 output ports:
#   - in from midi controller
#   - out to midi controller, for setting LEDs etc.
#   - out to Jamulus, with processed output (i.e. turn momentary switches into toggles)
# 
# use buffered jack backend to minimize impact on audio
# 
# automatically connect on startup.

# This script is lanuched in backgound before Jamulus is started
# Need to wait a few seconds before connecting to Jamulus
time.sleep(3)


# jack daemon maps alsa MIDI devices to port name like "midi_capture_1".
# In case of multiple MIDI devices, need to check which is X-TOUCH-MINI
target_alias='X-TOUCH-MINI'
client=jack.Client('mididings')
in_devices=client.get_ports(is_midi=True, is_output=True, is_physical=True)
out_devices=client.get_ports(is_midi=True, is_input=True, is_physical=True)
in_target = [ d.name for d in in_devices if target_alias in d.aliases[0] ][:1]
out_target = [ d.name for d in out_devices if target_alias in d.aliases[0] ][:1] 
if not in_target or not out_target:
    print('no MIDI device found matching alias ' + target_alias)
    sys.exit(1)

config(
      backend='jack',
      client_name='mididings',
      in_ports = [
          ('in', in_target[0]),
      ],
      out_ports = [
          ('out_1', out_target[0]),
          ('out_2', 'Jamulus:input midi')
      ],
      start_delay = 1
)

buttonState = [0] * 16;
master = alsaaudio.Mixer('Master')
capture = alsaaudio.Mixer('Capture')

#
# Convert the momentary on/off buttons to toggle events when the button press occurs
# Need to use NOTEOFF events, because X-touch mini 
# does not allow setting LED while button is down
#

def buttonLed(event):
    # convert the NOTEOFF event to 0 or 1 for setting controller LED
    button = event.note - 8
    value = event.velocity
    # toggle the button state and save it
    state = buttonState[button] = 1 if (buttonState[button] == 0) else 0
    event.velocity = state
    if state == 1:
        event.type = NOTEON
    # print (" - Note (%d, %d) => Note (%d, %d), Button: %d, State: %d" % (event.note, value, event.note, event.velocity, button, state));
    return event

def buttonOut(event):
    # convert the button LED note event to a control for Jamulus
    button = event.note - 8
    control = button + 19
    state = buttonState[button]
    value = 0 if (buttonState[button] == 0) else 127
    # print (" - Note (%d, %d) => Ctrl (%d, %d), Button: %d, State: %d" % (event.note, event.velocity, control, value, button, state));
    event.type = CTRL
    event.ctrl = control
    event.value = value
    return event

def alsaControl(event):
    # print (" - Ctrl (%d, %d)" % (event.ctrl, event.value));
    alsalevel = event.value * 100 // 127
    if event.ctrl == 9:
        master.setvolume(alsalevel)
    if event.ctrl == 10:
        capture.setvolume(alsalevel)
    return event

def layerBLedPan(event):
    event.value = 1
    event.ctrl = event.ctrl - 10
    return event

# X-Touch Mini sends events on midi channel 11.
# use jamulus --ctrlmidich string:  "11;f1*8;p11*8;m19*8;s27*8"
# send channel 11 controls 1-18 to Jamulus on port 2 to use for faders (layer A, controls 1-8) and pan (layer b, controls 11-18)
#
# send controls 9 & 10 to alsa for Master and Capture levels
#
# for NOTEOFF events from pushbutton, toggle the button state 
# and send back to x-touch mini on port1 to set LED state (convert to a NOTEON event to turn on LED)
# Also send to Jamulus on port 2 as a control event to set mute and solo buttons.
# Use controls above 18 to avoid conflict with physical controls
#

xtouchmini_patch = [
        # Print('Event') >> 
        ChannelFilter(11) >> [
        # Layer B pots for Level, send to Jamulus, set LED ring to "Single'
        CtrlFilter(1,2,3,4,5,6,7,8) >> [
            Port('out_2'),
            Ctrl('out_1', 1, EVENT_CTRL, 0)
        ],
        # Layer B pots for Pan, send to Jamulus, set LED ring to "Pan'
        CtrlFilter(11,12,13,14,15,16,17,18) >> [
            Port('out_2'),
            Process(layerBLedPan) >> Channel(1) >> Port('out_1')
        ],
        # Slider can control alsa levels.  Comment out next line if this is not wanted.
        CtrlFilter(9,10) >> Process(alsaControl) >> Discard(),
        # Pushbutton up sends toggles state, sends ctrl change to jamulus & sends LED state to pushbutton.
        # Use NOTEOFF instead of NOTEON because xtouch-mini will not allow LED to be set while button is down.
        (KeyFilter(8,23) & Filter(NOTEOFF)) % (Process(buttonLed) >> [
            Port('out_1'), 
            Process(buttonOut) >> Port('out_2')
        ])
    ]
]

jamulus_midi = SceneGroup('jamulus_midi', [
    Scene('xtouchmini', xtouchmini_patch, [
        [
            # Scene initialization events go here
            # set to Layer A
            Program('out_1', 1, 1) >> Print('Set Layer A')
        ],
    ])
])

run(
    # control=control,
    # pre=preScene,
    scenes={
        1: jamulus_midi
    }
)

