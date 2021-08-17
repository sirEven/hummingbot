#!/usr/bin/env python

class TA():

    def __init__(self, pattern, signal):
        self.__tick_count = 0
        self.__pattern = pattern
        self.__signal = signal

    @property
    def tick_count(self):
        return self.__tick_count
  
    def increment_tick_count(self):
        self.__tick_count += 1
    
    def reset_tick_count(self):
        self.__tick_count = 0

    def pattern(self):
        return self.__pattern

    @property
    def signal(self):
        return self.__signal