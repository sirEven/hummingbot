from typing import (
    List,
    Tuple,
)

from hummingbot.strategy.market_trading_pair_tuple import MarketTradingPairTuple
from hummingbot.strategy.technical_analysis import TechnicalAnalysisStrategy
from hummingbot.strategy.technical_analysis.technical_analysis_config_map import technical_analysis_config_map as c_map
from hummingbot.connector.exchange.paper_trade import create_paper_trade_market
from hummingbot.connector.exchange_base import ExchangeBase
from decimal import Decimal

from .ta.ta import TA

def start(self):
    try:
        exchange = c_map.get("derivative").value.lower()
        raw_trading_pair = c_map.get("market").value

        trading_pair: str = raw_trading_pair
        maker_assets: Tuple[str, str] = self._initialize_market_assets(exchange, [trading_pair])[0]
        market_names: List[Tuple[str, List[str]]] = [(exchange, [trading_pair])]
        self._initialize_wallet(token_trading_pairs=list(set(maker_assets)))
        self._initialize_markets(market_names)
        self.assets = set(maker_assets)
        maker_data = [self.markets[exchange], trading_pair] + list(maker_assets)
        self.market_trading_pair_tuples = [MarketTradingPairTuple(*maker_data)]
        asset_price_delegate = None

        # S: ta strategy specific parameters
        ta_pattern = c_map.get("ta_pattern").value
        time_resolution = c_map.get("time_resolution").value
        period = c_map.get("period").value
        candle_part = c_map.get("candle_part").value
        trade_volume = c_map.get("trade_volume").value

        strategy_logging_options = TechnicalAnalysisStrategy.OPTION_LOG_ALL

        # S: Beware of argument order... -.-
        self.strategy = TechnicalAnalysisStrategy(
            ta = TA(ta_pattern, time_resolution, period, candle_part, trade_volume),
            currently_processed_order_id = "",
            new_order_cooldown = False,
            market_info=MarketTradingPairTuple(*maker_data),
            logging_options=strategy_logging_options,
            asset_price_delegate=asset_price_delegate,
            hb_app_notification=True,
        )
    except Exception as e:
        self._notify(str(e))
        self.logger().error("Unknown error during initialization.", exc_info=True)
