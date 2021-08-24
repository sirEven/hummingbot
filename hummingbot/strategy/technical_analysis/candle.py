#!/usr/bin/env python

class Candle():

    def __init__(self, resolution, current_price, current_timestamp):
        self.__resolution = resolution
        self.__open_dt = current_timestamp
        self.__open = current_price
        self.__high = current_price
        self.__low = current_price
        self.__close = None
      
    @property
    def resolution(self):
        return self.__resolution

    @property
    def open_dt(self):
        return self.__open_dt

    @property
    def open(self):
        return self.__open
    
    @property
    def high(self):
        return self.__high

    def set_high(self, current_price):
        self.__high = current_price
    
    @property
    def low(self):
        return self.__low

    def set_low(self, current_price):
        self.__low = current_price

    @property
    def close(self):
        return self.__close

    def set_close(self, current_price):
        self.__close = current_price
    
    def update(self, current_price):
        if current_price > self.high:
            self.set_high(current_price)
        if current_price < self.low:
            self.set_low(current_price)    
    