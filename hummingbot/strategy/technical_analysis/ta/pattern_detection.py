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

    def run_pattern_detection(self, candles: List[Candle], logger):
        if self.__pattern == Pattern.hullMA.name:
            self.calculate_hullMA_signal(candles, self.__candle_part, logger)
    
    def calculate_hullMA_signal(self, candles: List[Candle], candle_part: CandlePart, logger):

        price_df = DataFrame.from_records([candle.to_dict() for candle in candles])
        headers=["timestamp_open", "open", "high", "low", "close"]
        price_df.columns = headers
        price_df = price_df.set_index('timestamp_open')
        price_df.index = pd.to_datetime(price_df.index, unit = 's')

        current_pattern_value = hull_ma(price_df[candle_part], len(candles))
        logger.info(f"Current hullMA: {current_pattern_value}")

        if self.__previous_pattern_value != None: 
            self.__current_signal = set_signal(self.__previous_pattern_value, current_pattern_value, self.__current_signal)

        if self.__current_signal != None:
            logger.info(f"Current SIGNAL: {self.__current_signal.name}")

        self.__previous_pattern_value = current_pattern_value