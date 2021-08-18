#!/usr/bin/env python

class TA():

    def __init__(self, pattern):
        self.__tick_count = 0
        self.__pattern = pattern
        self.__signal = "buy"

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