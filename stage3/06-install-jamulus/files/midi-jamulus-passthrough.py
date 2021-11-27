#!/usr/bin/python3

#
# Midi routing layer between jack and jamulus
# For Behringer X-Touch Mini MIDI controller
#
# This is a simple "pass-through" layer which takes
# all events coming in on jack midi port "in" and sends them to jamulus on port "out_2"
#
# it automatically makes the required jack midi connections.
#
# requires package python3-mididings from jambox-project repo,
#   sudo apt install python3-mididings
#
# jack creates midi ports with names like "midi_capture_1", "midi_playback_1"
# These names are used to automatically connect.
# If multiple MIDI devices are connected, listen and send to all of them.
# See the xtouchmini script for example of how to choose one specific device.


from mididings import *
from mididings.event import *
import time

#
# configure mididings with 1 input & 2 output ports:
#   - in from midi controller
#   - out_1 to midi controller, not used in this passthrough script..
#   - out_2 to Jamulus, for passing events from midi controller
# 
# use buffered jack backend to minimize impact on audio
# 
# automatically connect on startup.

# This script is lanuched in backgound before Jamulus is started
# Need to wait a few seconds before connecting to Jamulus
time.sleep(3)

config(
      backend='jack',
      client_name='mididings',
      in_ports = [
          ('in', 'system:midi_capture.*'),
      ],
      out_ports = [
          ('out_1', 'system:midi_playback.*'),
          ('out_2', 'Jamulus:input midi')
      ],
      start_delay = 1
)

passthrough_patch = [
        # pass all events from in_1 to Jamulus on port out_2
        PortFilter('in') >> Port('out_2')
]

jamulus_midi = SceneGroup('jamulus_midi', [
    Scene('passthrough', passthrough_patch, [
        [
            # Scene initialization events go here
        ],
    ])
])

run(
    scenes={
        1: jamulus_midi
    }
)

