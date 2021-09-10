#!/usr/bin/env python
from typing import List
from enum import Enum
from pandas import DataFrame
from .candle import Candle, CandlePart
from .mathematical_functions import hull_ma

# S: TODO: Derive new branch feature/pattern-detection
# S: TODO: FIND A GOOD WAY TO HANDLE DIFFERENT TA_PATTERNS
# S: TODO: Next step is to implement hullMA as first pattern. Then find an architecture to 
    # a) extend the patterns by additional technical analysis algorithms
    # b) enable a certain boolean combination of multiple technical analysis patterns 
        # e.g.: - "Only do hullMA signal trades when SMA200 is below current price"
        #       - "Only do hullMA signal trades when price is outside of Bollinger Bands"

class Pattern(Enum):
    hullMA = 1

class Signal(Enum):
    buy = 1
    sell = 2
    hold_long = 3
    hold_short = 4

class PatternDetection():
    def __init__(self, pattern: Pattern, candle_part: CandlePart):
        
        self.__pattern = pattern
        self.__candle_part = candle_part

        self.__previous_pattern_value = None
        self.__current_signal = None # S: set to "buy" to test bot-exchange interactions with live trading (Attention, this isn't paper trading)

        @property
        def current_signal(self):
            return self.__current_signal

    def run_pattern_detection(self, candles: List[Candle]):

        if self.__pattern == Pattern.hullMA:
            self.calculate_hullMA_signal(candles, self.__candle_part)
    
    def calculate_hullMA_signal(self, candles: List[Candle], candle_part: CandlePart):
        price_df = DataFrame.from_dict(candles, orient='index')
        current_pattern_value = hull_ma(price_df[CandlePart.close.name], len(candles))
        self.__current_signal = self.set_signal(self.__previous_pattern_value, current_pattern_value)

        self.__previous_pattern_value = current_pattern_value
    
    def set_signal(self, previous_pattern_value:float, current_pattern_value:float) -> Signal:
        
        new_signal: Signal = None
        
        if self.__current_signal == None: 
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.buy.name
            elif current_pattern_value < previous_pattern_value:
                new_signal = Signal.sell.name
        elif self.__current_signal == Signal.buy.name:
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.hold_long.name
            elif current_pattern_value < previous_pattern_value:
                new_signal = Signal.sell.name
        elif self.__current_signal == Signal.sell.name:
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.buy.name
            elif current_pattern_value < previous_pattern_value:
                new_signal = Signal.hold_short.name
        elif self.__current_signal == Signal.hold_long.name: 
            if current_pattern_value < previous_pattern_value:
                new_signal = Signal.sell.name
        elif self.__current_signal == Signal.hold_short: 
            if current_pattern_value > previous_pattern_value:
                new_signal = Signal.buy.name

        return new_signal


    





#     def hullMA(candles) -> Signal:
#         return Signal[candles[1]]

#     @property
#     def detect():
#         return {'hullMA': lambda candles: hullMA(candles)}

    

# patterndet = PatternDetection()
# candles = [1, 2, 3]
# patterndet.detect[Pattern.hullMA.name](candles)


# class Detection(object):
#     def pattern_to_signal(self, pattern: Pattern):
#         """Dispatch method"""
#         method_name = 'run_' + str(pattern)
#         # Get the method from 'self'. Default to a lambda.
#         method = getattr(self, method_name, lambda: "Pattern is not yet implemented.")
#         # Call the method as we return it
#         return method()
 
#     def run_hullMA(self, candles) -> Signal:
#       #  return "January"

# S: Sadly, we don't have switch cases with "match" keyword yet (post python 3.10)
# class Signal():
#     def __init__(self, pattern: Pattern):
#         self.__pattern = pattern()
    
#     def analyse(self, candles):
#         match self.__pattern:
#             case "hullMA":
#               print("hullMA-logic here")
