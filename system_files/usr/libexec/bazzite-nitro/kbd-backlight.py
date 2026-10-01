#!/usr/bin/python3
# Set the keyboard backlight on the ENE KB5130 controller (0CF2:5130).
# The controller starts dark and no kernel driver sets it.
# Usage: kbd-backlight.py /dev/hidrawN BRIGHTNESS(0-100) RRGGBB
import fcntl
import os
import sys

device, brightness, color = sys.argv[1], int(sys.argv[2]), bytes.fromhex(sys.argv[3])
if not 0 <= brightness <= 100 or len(color) != 3:
    sys.exit("usage: kbd-backlight.py /dev/hidrawN BRIGHTNESS(0-100) RRGGBB")

# Feature report 0xa4: keyboard target, static mode, brightness, speed, direction,
# red, green, blue, zone mask for all four zones
report = bytearray([0xA4, 0x21, 0x02, brightness, 0, 0, *color, 0x0F, 0x00])
# HIDIOCSFEATURE(len)
request = (3 << 30) | (len(report) << 16) | (ord("H") << 8) | 0x06
fcntl.ioctl(os.open(device, os.O_RDWR), request, report)
