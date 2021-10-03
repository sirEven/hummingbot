#!/usr/bin/env python

from .technical_analysis import TechnicalAnalysisStrategy
from hummingbot.strategy.asset_price_delegate import AssetPriceDelegate
from hummingbot.strategy.order_book_asset_price_delegate import OrderBookAssetPriceDelegate
from hummingbot.strategy.api_asset_price_delegate import APIAssetPriceDelegate
__all__ = [
    TechnicalAnalysisStrategy,
    AssetPriceDelegate,
    OrderBookAssetPriceDelegate,
    APIAssetPriceDelegate
]