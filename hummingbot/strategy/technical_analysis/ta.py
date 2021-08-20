#!/usr/bin/env python

class TA():

    def __init__(self, pattern, time_resolution, period, candle_part, trade_volume):
        self.__pattern = pattern
        self.__time_resolution = time_resolution
        self.__period = period
        self.__candle_part = candle_part
        self.__trade_volume = trade_volume
       
        self.__signal = "hold"
        self.__tick_count = 0

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
    def cancdle_part(self):
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
    
    def increment_tick_count(self):
        self.__tick_count += 1
    
    def reset_tick_count(self):
        self.__tick_count = 0

    def pattern(self):
        return self.__pattern
    
    def switch_signal(self):
        if self.__signal == "buy":
            self.__signal = "sell"
        elif self.__signal == "sell":
            self.__signal = "buy"