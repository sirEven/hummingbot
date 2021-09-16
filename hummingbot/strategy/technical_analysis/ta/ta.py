#!/usr/bin/env python

from .pattern_detection import PatternDetection, Pattern
from .candle import Candle, CandlePart

class TA():

    def __init__(self, pattern: Pattern, time_resolution: int, period: int, candle_part: CandlePart, trade_volume: int):
        self.__pattern_detection = PatternDetection(pattern, candle_part)
        self.__time_resolution = time_resolution
        self.__period = period
        self.__trade_volume = trade_volume
       
        self.__tick_count = -5 # S: we give hummingbot some time to spin up everything
        self.__current_candle = None
        self.__candles = []

        self.__logger = None # S: TODO: Debugging, plz remove later
    
    @property
    def signal(self):
        return self.__pattern_detection.current_signal

    @property
    def time_resolution(self):
        return self.__time_resolution
    
    @property
    def period(self):
        return self.__period
    
    @property
    def trade_volume(self):
        return self.__trade_volume

    @property
    def tick_count(self):
        return self.__tick_count
    
    @property
    def current_candle(self):
        return self.__current_candle
    
    @property
    def candles(self):
        return self.__candles
    
    @property
    def resolution_not_done(self) -> bool:
        return self.tick_count < self.time_resolution # & self.tick_count != 0 
    
    @property
    def resolution_done(self) -> bool:
        return self.__tick_count == self.__time_resolution

    @property
    def current_tick_is_zero(self) -> bool:
        return self.__tick_count == 0
    
    @property
    def candles_shifted(self) -> bool:
        return self.__candles_shifted
    
    def open_current_candle(self, current_price, current_timestamp):
        self.__current_candle = Candle(current_price, current_timestamp)
    
    def increment_tick_count(self):
        self.__tick_count += 1
    
    def reset_tick_count(self):
        self.__tick_count = 0

    def update_current_candle(self, current_price):
        if self.__current_candle != None:
            self.__current_candle.update(current_price)
    
    def close_current_candle(self, current_price):
        self.__current_candle.set_close(current_price)
    
    def move_current_candle(self):
        self.__candles.append(self.__current_candle)
        if len(self.__candles) > self.__period:
            self.__candles.pop(0)

    def track_and_analyze_candles(self, logger, current_price, current_timestamp):
        self.__logger = logger
        if self.current_tick_is_zero:
                self.open_current_candle(current_price, current_timestamp)

        self.increment_tick_count()

        if self.resolution_not_done:
            if self.current_candle is not None:
                self.update_current_candle(current_price)
        
        if self.resolution_done:
            self.close_current_candle(current_price)
            
            self.move_current_candle()
            logger.info(f"Number of Candles: {len(self.candles)}")

            if len(self.__candles) == self.__period:
                self.__pattern_detection.run_pattern_detection(self.__candles, self.__logger)

            self.reset_tick_count()

# funcs for debugging
    def tick_alert(self, logger, current_tick):
        if current_tick < 0:
            logger.info(f"Bot starts in {abs(current_tick)}.")
        else:
            # logger.info("Current Tick: {}.".format(current_tick))
            pass

    def remove_all_candles(self):
        self.__candles = []