#!/usr/bin/env python
from typing import List
from enum import Enum
import pandas as pd
from pandas import DataFrame
from .candle import Candle, CandlePart
from .mathematical_functions import hull_ma
from .signal import Signal, set_signal

# S: TODO: Find an architecture to 
    # a) extend the patterns by additional technical analysis algorithms
    # b) enable a certain boolean combination of multiple technical analysis patterns 
        # e.g.: - "Only do hullMA signal trades when SMA200 is below current price"
        #       - "Only do hullMA signal trades when price is outside of Bollinger Bands"

class Pattern(Enum):
    hullMA = 1

class PatternDetection():
    def __init__(self, pattern: Pattern, candle_part: CandlePart):
        self.__pattern = pattern
        self.__candle_part = candle_part

        self.__previous_pattern_value = None
        self.__current_signal: Signal = None 

    @property
    def current_signal(self):
        return self.__current_signal
    
    def set_current_signal(self, value):
        self.__current_signal = value

    def set_previous_pattern_value(self, value):
        self.__previous_pattern_value = value

    def run_pattern_detection(self, candles: List[Candle], period: int, logger):

        if self.__pattern == Pattern.hullMA.name:
            self.calculate_hullMA_crossover_signal(candles, period, self.__candle_part, self.__previous_pattern_value, logger)
    
    def calculate_hullMA_crossover_signal(self, candles: List[Candle], period: int, candle_part: CandlePart, previous_pattern_value: float, logger):

        if len(candles) == period:
                
            price_df = DataFrame.from_records([candle.to_dict() for candle in candles])
            headers=["timestamp_open", "open", "high", "low", "close"]
            price_df.columns = headers
            price_df = price_df.set_index('timestamp_open')
            price_df.index = pd.to_datetime(price_df.index, unit = 's')

            current_pattern_value = hull_ma(price_df[candle_part], len(candles))
            logger.info(f"Current hullMA: {current_pattern_value}")

            if previous_pattern_value != None: 
                self.__current_signal = set_signal(previous_pattern_value, current_pattern_value, self.__current_signal)

            if self.__current_signal != None:
                logger.info(f"Current SIGNAL: {self.__current_signal.name}")

            self.set_previous_pattern_value(current_pattern_value)

# S: TODO: WIP -> hullMA crossover vs. hullMA Slope & Signal - how to differentiate several periods and signal combination (set_signal() as is but used twice)