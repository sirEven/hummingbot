#!/usr/bin/env python

from enum import Enum

class Signal(Enum):
    buy = 1
    sell = 2
    hold_long = 3
    hold_short = 4

def set_signal(previous_pattern_value:float, current_pattern_value:float, current_signal: Signal) -> Signal:

        new_signal: Signal = None

        if current_signal == None: 
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.buy
            elif current_pattern_value < previous_pattern_value:
                new_signal = Signal.sell
            
            return new_signal

        elif current_signal == Signal.buy:
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.hold_long
            elif current_pattern_value < previous_pattern_value:
                new_signal = Signal.sell

        elif current_signal == Signal.sell:
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.buy
            elif current_pattern_value < previous_pattern_value:
                new_signal = Signal.hold_short

        elif current_signal == Signal.hold_long: 
            if current_pattern_value < previous_pattern_value:
                new_signal = Signal.sell
            else: 
                new_signal = Signal.hold_long

        elif current_signal == Signal.hold_short: 
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.buy
            else:
                new_signal = Signal.hold_short

        return new_signal

def switch_to_hold_immediately_on_new_signal(current_signal:Signal) -> Signal:

    new_signal: Signal = None

    if current_signal == Signal.buy:
        new_signal = Signal.hold_long
    elif current_signal == Signal.sell:
        new_signal = Signal.hold_short

    return new_signal