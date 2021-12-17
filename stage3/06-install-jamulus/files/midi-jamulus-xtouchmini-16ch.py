#!/usr/bin/python3
#
# Midi routing layer between jack and jamulus
# For Behringer X-Touch Mini MIDI controller
#
# Layer A: control 8 jamulus channels 0-7   (slider controls ALSA master level)
# Layer B: Control 8 jamulus channels 8-15  (slider controls ALSA capture level)
#
#    Rotary encoder has 2 states (push to toggle between states)
#       1. fader (led ring display "fan" pattern, init full volume)
#       2. pan   (led ring displays "pan" pattern, init center) 
#    Top button:    "Mute"
#    Bottom button: "Solo"
#
# X-Touch mini does not send layer change message.
# this script cannot detect a layer change until an event happens on new layer.
# So it is required to push a button or move an encoder after layer change,
# in order to refresh the encoder led ring state.
#
# Converts momentary pushbuttons and encoder push switches (which send midi note events) 
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
import re

master = alsaaudio.Mixer('Master')
capture = alsaaudio.Mixer('Capture')

currentLayer = 0

jamulusChannel = 11
jamulusOutPort = 'out_2'
controllerChannel = 11
controllerGlobalChannel = 1
controllerOutPort = 'out_1'

ledRingSingle = 0
ledRingPan = 1
ledRingFan = 2
ledRingSpread = 3
ledRingTrim = 4

#
# configure mididings with 1 input & 2 output ports:
#   - in from midi controller
#   - out to midi controller, for setting LEDs etc.
#   - out to Jamulus, with processed output (i.e. turn momentary switches into toggles)
# 
# use buffered jack backend to minimize impact on audio
# 
# automatically connect MIDI ports on startup.

# This script is lanuched in backgound before Jamulus is started
# Need to wait a few seconds before connecting to Jamulus
time.sleep(3)

# Jack has multiple mechanisms for sending alsa MIDI ports to Jack MIDI ports.
# All name the jack ports differently, and we want to work with them all.
# Mididings can use a regexp to look for a matching jack MIDI port
#
target_alias = '^.*X-TOUCH.MINI.*'   # regexp allowed
client=jack.Client('mididings')

config(
      backend='jack',
      client_name='mididings',
      in_ports = [
          ('in', target_alias ),
      ],
      out_ports = [
          (controllerOutPort, target_alias ),
          (jamulusOutPort, 'Jamulus:input midi')
      ],
      start_delay = 1
)

# there are 48 "buttons" on x-touch mini, on 2 layers (A & B)
# 8 x encoder push switches   Layer A:  0-7    Layer B: 24-31
# 8 pushbuttons row 1         Layer A:  8-15   Layer B: 32-39
# 8 pushbuttons row 2         Layer A:  16-23  Layer B: 40-47
# x 2 layers
#
# save a toggle state for each one whether we intend to use it or not
# encoders:     0=fader (ledRing=fan)   1=pan (ledRing=pan)
# pushbuttons:  0=off   (led off)       1=on  (led on)
#
buttonState = [0] * 48

# Encoders will serve as both fader and pan, 
# Encoder push switch will toggle state.
# LED setting of encoder will serve as visual feedback of current encoder state.
# For each encoder, save latest value so it can be restored on state change.
#
# There are 3 values for each encoder:
# encoderState (0=fader, 1=pan)
# faderValue
# panValue
encoderState = [0] * 19   # initialize to "fader" state 
faderValue = [127] * 19   # initialize to full volume  
panValue = [64] * 19      # initialize to pan center

#
# noteTable is a list of tuples, indexed by the note number 0-47
# the tuples contain:
#    ( note, layer, jamulusControlNumber, encoderControlNumber )
#
#  note: note number that will toggle state
#  layer: 0=Layer A, 1=Layer B
#  jamulusControlNumber:  Control number to send to Jamulus (for mute & solo buttons)
#  encoderControlNumber:  Control number in xtouch-mini to send restored encoder value
#
noteTable = [
        (0, 0, None, 1),           # Layer A encoder push switches
        (1, 0, None, 2),
        (2, 0, None, 3),
        (3, 0, None, 4),
        (4, 0, None, 5),
        (5, 0, None, 6),
        (6, 0, None, 7),
        (7, 0, None, 8),
        (8, 0, 19, None),          # Layer A pushbuttons row 1 (mute 1-8) 
        (9, 0, 20, None),
        (10, 0, 21, None),
        (11, 0, 22, None),
        (12, 0, 23, None),
        (13, 0, 24, None),
        (14, 0, 25, None),
        (15, 0, 26, None),
        (16, 0, 35, None),         # Layer A pushbuttons row 2 (solo 1-8)
        (17, 0, 36, None),
        (18, 0, 37, None),
        (19, 0, 38, None),
        (20, 0, 39, None),
        (21, 0, 40, None),
        (22, 0, 41, None),
        (23, 0, 42, None),
        (24, 1, None, 11),         # Layer B encoder push switches
        (25, 1, None, 12),
        (26, 1, None, 13),
        (27, 1, None, 14),
        (28, 1, None, 15),
        (29, 1, None, 16),
        (30, 1, None, 17),
        (31, 1, None, 18),
        (32, 1, 27, None),         # Layer B pushbuttons row 1 (mute 9-16)
        (33, 1, 28, None),
        (34, 1, 29, None),
        (35, 1, 30, None),
        (36, 1, 31, None),
        (37, 1, 32, None),
        (38, 1, 33, None),
        (39, 1, 34, None),
        (40, 1, 43, None),         # Layer B pushbuttons row 2 (solo 9-16)
        (41, 1, 44, None),
        (42, 1, 45, None),
        (43, 1, 46, None),
        (44, 1, 47, None),
        (45, 1, 48, None),
        (46, 1, 49, None),
        (47, 1, 50, None)
    ]

# There are 18 controls on x-touch mini
# 8 encoders              Layer A: 1-8     Layer B: 11-18
# 1 slider                Layer A: 9       Layer B: 10
# x 2 layers
#
# controlTable is a list of tuples, indexed by the control number 0-18
# the tuples contain:
#   (encoderControlNumber, layer, ledRing, controlOutFader, controlOutPan )
#
#  encoderControlNumber:  Control number in xtouch-mini to receive, also to send restored encoder value
#  layer: 0=Layer A, 1=Layer B
#  ledRing: Control number to send to xtouch-mini to set led Ring behavior (fan for fader, pan for pan)
#  controlOutFader:  Control number to send to Jamulus for fader when in fader state
#  controlOutPan:  Control number to send to Jamulus for pan when in pan state
#
controlTable = [
        (0, None, None, None, None),   # contol number 0 not used
        (1, 0, 1, 1, 51),              # layer A encoders 1-8
        (2, 0, 2, 2, 52),
        (3, 0, 3, 3, 53),
        (4, 0, 4, 4, 54),
        (5, 0, 5, 5, 55),
        (6, 0, 6, 6, 56),
        (7, 0, 7, 7, 57),
        (8, 0, 8, 8, 58),
        (9, 0, None, None, None),      # Layer A slider
        (10, 1, None, None, None),     # Layer B slider
        (11, 1, 1, 9, 59),             # layer B encoders 9-16
        (12, 1, 2, 10, 60),
        (13, 1, 3, 11, 61),
        (14, 1, 4, 12, 62),
        (15, 1, 5, 13, 63),
        (16, 1, 6, 14, 64),
        (17, 1, 7, 15, 65),
        (18, 1, 8, 16, 66)
    ]

def controllerInit(event,newLayer):
    return layerChangeEvents(newLayer) + controllerButtonsRestore()

def controllerButtonsRestore():
    # restore controller buttons LED state from buttonState table.
    # xtouch mini retains pushbutton LED state across layer changes.
    # so this function is only called at startup.
    events = []
    for note in noteTable:
        ( noteNumber, layer, jamulusControlNumber, encoderControlNumber ) = note
        if jamulusControlNumber is not None:
            if buttonState[noteNumber] == 0:
                events.append(NoteOffEvent(controllerOutPort, controllerChannel, noteNumber, 0))
            else:
                events.append(NoteOnEvent(controllerOutPort, controllerChannel, noteNumber, 1))
    return events

def layerChangeEvents(newLayer):
    # pushbutton switches retain their state across layer changes.
    # but encoder LED ring state is not remembered.
    #
    # Create a list of event to send to xtouch mini, at init time, or when layer change is detected.
    # This will set encoder values and ledRings to correct state.
    events = []
    for control in controlTable:
        (encoderControlNumber, layer, ledRing, controlOutFader, controlOutPan) = control
        if (layer is not None) and (layer == newLayer) and (ledRing is not None):
            # restore state of encoder
            ledRing = controlTable[encoderControlNumber][2]
            state = encoderState[encoderControlNumber]
            if state == 0:
                encValue = faderValue[encoderControlNumber]
                encLedRing = ledRingFan
            else:
                encValue = panValue[encoderControlNumber]
                encLedRing = ledRingPan
            events.append(CtrlEvent(controllerOutPort, controllerChannel, encoderControlNumber, encValue))
            events.append(CtrlEvent(controllerOutPort, controllerGlobalChannel, ledRing, encLedRing))
    return events

#
# Convert the momentary on/off buttons to toggle events when the button press occurs
# Need to use NOTEOFF events, because X-touch mini 
# does not allow setting LED while button is down
#
def noteOff(event):
    global currentLayer
    events = []
    try:
        button = event.note
        value = event.velocity
        # toggle the button state and save it
        state = buttonState[button] = 1 if (buttonState[button] == 0) else 0
        _, layer, jamulusControlNumber, encoderControlNumber = noteTable[button]
        if layer != currentLayer:
            events.extend(layerChangeEvents(layer))
            currentLayer = layer

        if jamulusControlNumber is not None:
            # this "note" is a pushbutton switch that gets sent to Jamulus as a control event
            # send new LED state back to x-touch mini on same note number,
            # send control event to Jamulus on mapped control number
            if state == 0:
                events.append(NoteOffEvent(controllerOutPort, controllerChannel, event.note, 0))
            else:
                events.append(NoteOnEvent(controllerOutPort, controllerChannel, event.note, 1))
            events.append(CtrlEvent(jamulusOutPort, jamulusChannel, jamulusControlNumber, 0 if state == 0 else 127))

        elif encoderControlNumber is not None:
            # this "note" is an encoder push switch, not a pushbutton.
            # Get the control properties
            ledRing = controlTable[encoderControlNumber][2]
            # save a copy of the state in encoderState table for lookup by control number
            encoderState[encoderControlNumber] = state
            if state == 0:
                encValue = faderValue[encoderControlNumber]
                encLedRing = ledRingFan
            else:
                encValue = panValue[encoderControlNumber]
                encLedRing = ledRingPan

            # send new LED Ring state back to x-touch mini as control message on correct number
            # send restored encoder value back to x-touch mini as control message on correct number
            events.append(CtrlEvent(controllerOutPort, controllerChannel, encoderControlNumber, encValue))
            events.append(CtrlEvent(controllerOutPort, controllerGlobalChannel, ledRing, encLedRing))

    except Exception as e:
        print(e)

    return events

# Process control value changes.
# Update the stored value, and send to jamulus channel based on the encoder state (fader or pan).
# Sliders are used as alsa controls for Master & Capture, not sent to Jamulus
def controlChange(event):
    global currentLayer
    events = []
    try:
        controlIn = event.ctrl
        _, layer, ledRing, controlOutFader, controlOutPan = controlTable[controlIn]
        if layer != currentLayer:
            events.extend(layerChangeEvents(layer))
            currentLayer = layer

        if controlIn in (9,10):
            # controls 9 and 10 are sliders
            # process sliders to control alsa levels, don't send to Jamulus
            alsaLevel = event.value * 100 // 127
            if controlIn == 9:
                master.setvolume(alsaLevel)
            elif controlIn == 10:
                capture.setvolume(alsaLevel)

        else:
            encState = encoderState[controlIn]
            # update the stored value (fader or pan) based on encState
            if encState == 0:
                faderValue[controlIn] = event.value
                jamulusOutCtrl = controlOutFader
                ledRingState = ledRingFan
            else:
                panValue[controlIn] = event.value
                jamulusOutCtrl = controlOutPan
                ledRingState = ledRingPan
            # send the control value to Jamulus on the correct channel based on encState
            events.append(CtrlEvent(jamulusOutPort, jamulusChannel, jamulusOutCtrl, event.value))
            # send the ledRing value to controller on the correct channel based on encState
            events.append(CtrlEvent(controllerOutPort, controllerGlobalChannel, ledRing, ledRingState))

    except Exception as e:
        print(e)

    return events

# X-Touch Mini sends events on midi channel 11.
# use jamulus --ctrlmidich string:  "11;f1*16;m19*16;s35*16;p51*16"
# send channel 11 controls 1-18 to Jamulus on port 2 to use for faders (layer A, controls 1-8) and pan (layer b, controls 11-18)
#
# send controls 9 & 10 to alsa for Master and Capture levels
#
# for NOTEOFF events from pushbutton, toggle the button state 
# and send back to x-touch mini on port1 to set LED state (convert to a NOTEON event to turn on LED)
# Also send to Jamulus on port 2 as a control event to set mute and solo buttons.
# Use controls above 18 to avoid conflict with physical controls
#
xtouchmini_patch16 = [
        ChannelFilter(11) >> [
            # Process control changes
            CtrlFilter(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18) % Process(controlChange),
            # Process button presses on NOTEOFF event
            (KeyFilter(0,48) & Filter(NOTEOFF)) % Process(noteOff)
        ]
]

jamulus_midi = SceneGroup('jamulus_midi', [
    Scene('xtouchmini', xtouchmini_patch16, [
        [
            # Scene initialization events go here
            # set to standard mode (not Mackie Control)
            Ctrl(controllerOutPort, controllerGlobalChannel, 127, 0),
            # set to Layer A
            Program(controllerOutPort, controllerGlobalChannel, 1),
            # initialize controller encoder values and LED ring states
            Process(controllerInit,0)
        ]
    ])
])

run(
    # control=control,
    # pre=preScene,
    scenes={
        1: jamulus_midi
    }
)

