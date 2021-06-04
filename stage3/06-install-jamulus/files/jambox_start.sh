#!/bin/bash

# On first boot, if hifiberry DAC+ ADC Pro is visible in /proc/device-tree, enable in /boot/config.txt and reboot
if [ -f /proc/device-tree/hat/product ]; then
  if grep -q 'DAC+ ADC Pro' /proc/device-tree/hat/product; then
    if grep -q '^#force_eeprom_read=0' /boot/config.txt; then
      if grep -q '^#dtoverlay=hifiberry-dacplusadcpro' /boot/config.txt; then
        sudo sed -i 's/^#force_eeprom_read=0/force_eeprom_read=0/' /boot/config.txt
        sudo sed -i 's/^#dtoverlay=hifiberry-dacplusadcpro/dtoverlay=hifiberry-dacplusadcpro/' /boot/config.txt
        sudo reboot
      fi
    fi
  fi
fi

if [ -f ~/.config/Jamulus/jamulus_start.conf ]; then
  source ~/.config/Jamulus/jamulus_start.conf
  if [[ "$JAMULUS_AUTOSTART" == '1' ]]; then
   jamulus_start.sh
   exit 0
  fi
fi

if [ -f ~/.config/sonobus_start.conf ]; then
  source ~/.config/sonobus_start.conf
  if [[ "$SONOBUS_AUTOSTART" == '1' ]]; then
   sonobus_start.sh
   exit 0
  fi
fi

if [ -f ~/.config/JammerNetz/jammernetz_start.conf ]; then
  source ~/.config/JammerNetz/jammernetz_start.conf
  if [[ "$JAMMERNETZ_AUTOSTART" == '1' ]]; then
   jammernetz_start.sh
   exit 0
  fi
fi
