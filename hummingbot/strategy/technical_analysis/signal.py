#!/usr/bin/env python

from enum import Enum

class Signal(Enum):
    buy = 1
    sell = 2
    hold_long = 3
    hold_short = 4