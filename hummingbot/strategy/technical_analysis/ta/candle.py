#!/usr/bin/env python

from enum import Enum

class CandlePart(Enum):
    open = 1
    high = 2
    low = 3
    close = 4

class Candle():
    def __init__(self, current_price, current_timestamp):
        self.__timestamp_open = current_timestamp
        self.__open = current_price
        self.__high = current_price
        self.__low = current_price
        self.__close = None

    def to_dict(self):
        return {
            'timestamp_open': self.__timestamp_open,
            'open': self.__open,
            'high': self.__high,
            'low': self.__low,
            'close': self.__close,
        }

    @property
    def timestamp_open(self):
        return self.__timestamp_open

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
    