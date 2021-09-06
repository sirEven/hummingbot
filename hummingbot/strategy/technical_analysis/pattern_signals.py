#!/usr/bin/env python
from enum import Enum

# S: TODO: FIND A GOOD WAY TO HANDLE DIFFERENT TA_PATTERNS
# S: TODO: Next step is to implement hullMA as first Ppattern. Then find an architecture to 
    # a) extend the patterns by further technical analysis algorithms
    # b) enable a certain boolean combination of multiple technical analysis patterns 
        # e.g.: - "Only do hullMA signal trades when SMA200 is below current price"
        #       - "Only do hullMA signal trades when price is outside of Bollinger Bands"

class Pattern(Enum):
    hullMA = 1

class Signal(Enum):
    "buy" = 1
    "sell" = 2
    "hold_long" = 3
    "hold_short" = 4

class PatternDetection():
    def __init__(self) -> None:
        pass












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
