#!/usr/bin/env python

from .candle import Candle

class TA():

    def __init__(self, pattern, time_resolution, period, candle_part, trade_volume):
        self.__pattern = pattern
        self.__time_resolution = time_resolution
        self.__period = period
        self.__candle_part = candle_part
        self.__trade_volume = trade_volume
       
        self.__signal = "hold"
        self.__tick_count = -5 # S: we give the bot some time to spin up everything
        self.__current_candle = None
        self.__candles = []

    @property
    def pattern(self):
        return self.__pattern
    
    @property
    def time_resolution(self):
        return self.__time_resolution
    
    @property
    def period(self):
        return self.__period

    @property
    def candle_part(self):
        return self.__candle_part
    
    @property
    def trade_volume(self):
        return self.__trade_volume

    @property
    def tick_count(self):
        return self.__tick_count
    
    @property
    def signal(self):
        return self.__signal
    
    @property
    def current_candle(self):
        return self.__current_candle
    
    @property
    def candles(self):
        return self.__candles
    
    @property
    def candle_not_done(self) -> bool:
        return self.tick_count < self.time_resolution # & self.tick_count != 0 
    
    @property
    def resolution_done(self) -> bool:
        return self.__tick_count == self.__time_resolution

    @property
    def tick_count_is_zero(self) -> bool:
        return self.__tick_count == 0
    
    def open_current_candle(self, current_price, current_timestamp):
        self.__current_candle = None
        self.__current_candle = Candle(self.time_resolution, current_price, current_timestamp)
    
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
    
    def switch_signal(self):
        if self.__signal == "buy":
            self.__signal = "sell"
        elif self.__signal == "sell":
            self.__signal = "buy"