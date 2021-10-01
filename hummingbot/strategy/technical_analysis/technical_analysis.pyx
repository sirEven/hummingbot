from decimal import Decimal
import logging
import pandas as pd
import numpy as np
from typing import (
    List,
    Dict,
    Optional
)
from math import (
    floor,
    ceil
)
import time
from hummingbot.core.clock cimport Clock
from hummingbot.core.event.events import (
    TradeType,
    PriceType,
    PositionAction,
    PositionSide,
    PositionMode
)
from hummingbot.core.data_type.limit_order cimport LimitOrder
from hummingbot.core.data_type.limit_order import LimitOrder
from hummingbot.core.network_iterator import NetworkStatus
from hummingbot.connector.exchange_base import ExchangeBase
from hummingbot.connector.exchange_base cimport ExchangeBase
from hummingbot.core.event.events import OrderType

from hummingbot.strategy.market_trading_pair_tuple import MarketTradingPairTuple
from hummingbot.strategy.strategy_base import StrategyBase
from hummingbot.client.config.global_config_map import global_config_map

from .data_types import (
    Proposal,
    PriceSize
)
from .perpetual_market_making_order_tracker import PerpetualMarketMakingOrderTracker

from .asset_price_delegate cimport AssetPriceDelegate
from .asset_price_delegate import AssetPriceDelegate
from .order_book_asset_price_delegate cimport OrderBookAssetPriceDelegate

from .ta.ta import TA
from .ta.pattern_detection import PatternDetection, Signal

NaN = float("nan")
s_decimal_zero = Decimal(0)
s_decimal_neg_one = Decimal(-1)
pmm_logger = None


cdef class TechnicalAnalysisStrategy(StrategyBase):
    OPTION_LOG_CREATE_ORDER = 1 << 3
    OPTION_LOG_MAKER_ORDER_FILLED = 1 << 4
    OPTION_LOG_STATUS_REPORT = 1 << 5
    OPTION_LOG_ALL = 0x7fffffffffffffff

    # These are exchanges where you're expected to expire orders instead of actively cancelling them.
    RADAR_RELAY_TYPE_EXCHANGES = {"radar_relay", "bamboo_relay"}

    @classmethod
    def logger(cls):
        global pmm_logger
        if pmm_logger is None:
            pmm_logger = logging.getLogger(__name__)
        return pmm_logger

    def __init__(self,
                 ta: TA,
                 currently_processed_order_id: str,
                 new_order_cooldown: bool,  
                 market_info: MarketTradingPairTuple,
                #  position_mode: str,
                #  bid_spread: Decimal,
                #  ask_spread: Decimal,
                order_amount: Decimal,
                #  position_management: str,
                #  long_profit_taking_spread: Decimal,
                #  short_profit_taking_spread: Decimal,
                #  ts_activation_spread: Decimal,
                #  ts_callback_rate: Decimal,
                #  stop_loss_spread: Decimal,
                #  close_position_order_type: str,
                #  order_levels: int = 1,
                #  order_level_spread: Decimal = s_decimal_zero,
                #  order_level_amount: Decimal = s_decimal_zero,
                #  order_refresh_time: float = 30.0,
                #  order_refresh_tolerance_pct: Decimal = s_decimal_neg_one,
                filled_order_delay: float = 1.0, # S: Attention, here we set fixed delay!
                #  hanging_orders_enabled: bool = False,
                #  hanging_orders_cancel_pct: Decimal = Decimal("0.1"),
                #  order_optimization_enabled: bool = False,
                #  ask_order_optimization_depth: Decimal = s_decimal_zero,
                #  bid_order_optimization_depth: Decimal = s_decimal_zero,
                 leverage: int = 1,
                 add_transaction_costs_to_orders: bool = False,
                 asset_price_delegate: AssetPriceDelegate = None,
                 price_type: str = "mid_price",
                #  take_if_crossed: bool = False,
                #  price_ceiling: Decimal = s_decimal_neg_one,
                #  price_floor: Decimal = s_decimal_neg_one,
                #  ping_pong_enabled: bool = False,
                 logging_options: int = OPTION_LOG_ALL,
                 status_report_interval: float = 900,
                #  minimum_spread: Decimal = Decimal(0),
                 hb_app_notification: bool = False,
                #  order_override: Dict[str, List[str]] = {},
                 ):

        # if price_ceiling != s_decimal_neg_one and price_ceiling < price_floor:
        #     raise ValueError("Parameter price_ceiling cannot be lower than price_floor.")

        super().__init__()
        self._ta = ta
        self._currently_processed_order_id = currently_processed_order_id
        self._new_order_cooldown = new_order_cooldown
        self._sb_order_tracker = PerpetualMarketMakingOrderTracker()
        self._market_info = market_info
        self._leverage = leverage
        # self._position_mode = PositionMode.HEDGE if position_mode == "Hedge" else PositionMode.ONEWAY
        # self._bid_spread = bid_spread
        # self._ask_spread = ask_spread
        # self._minimum_spread = minimum_spread
        self._order_amount = order_amount
        # self._position_management = position_management
        # self._long_profit_taking_spread = long_profit_taking_spread
        # self._short_profit_taking_spread = short_profit_taking_spread
        # self._ts_activation_spread = ts_activation_spread
        # self._ts_callback_rate = ts_callback_rate
        # self._stop_loss_spread = stop_loss_spread
        # self._close_position_order_type = OrderType.MARKET if close_position_order_type == "MARKET" else OrderType.LIMIT
        # self._order_levels = order_levels
        # self._buy_levels = order_levels
        # self._sell_levels = order_levels
        # self._order_level_spread = order_level_spread
        # self._order_level_amount = order_level_amount
        # self._order_refresh_time = order_refresh_time
        # self._order_refresh_tolerance_pct = order_refresh_tolerance_pct
        self._filled_order_delay = filled_order_delay
        # self._hanging_orders_enabled = hanging_orders_enabled
        # self._hanging_orders_cancel_pct = hanging_orders_cancel_pct
        # self._order_optimization_enabled = order_optimization_enabled
        # self._ask_order_optimization_depth = ask_order_optimization_depth
        # self._bid_order_optimization_depth = bid_order_optimization_depth
        self._add_transaction_costs_to_orders = add_transaction_costs_to_orders
        self._asset_price_delegate = asset_price_delegate
        self._price_type = self.get_price_type(price_type)
        # self._take_if_crossed = take_if_crossed
        # self._price_ceiling = price_ceiling
        # self._price_floor = price_floor
        # self._ping_pong_enabled = ping_pong_enabled
        # self._ping_pong_warning_lines = []
        self._hb_app_notification = hb_app_notification
        # self._order_override = order_override
        self._cancel_timestamp = 0
        self._create_timestamp = 0
        self._all_markets_ready = False
        self._filled_buys_balance = 0
        self._filled_sells_balance = 0
        self._hanging_order_ids = []
        self._logging_options = logging_options
        self._last_timestamp = 0
        self._status_report_interval = status_report_interval
        self._last_own_trade_price = Decimal('nan')
        self._ts_peak_bid_price = Decimal('0')
        self._ts_peak_ask_price = Decimal('0')
        self._exit_orders = []
        self._next_buy_exit_order_timestamp = 0
        self._next_sell_exit_order_timestamp = 0

        self.c_add_markets([market_info.market])

    def all_markets_ready(self):
        return all([market.ready for market in self._sb_markets])

    @property
    def order_refresh_tolerance_pct(self) -> Decimal:
        return self._order_refresh_tolerance_pct

    @order_refresh_tolerance_pct.setter
    def order_refresh_tolerance_pct(self, value: Decimal):
        self._order_refresh_tolerance_pct = value

    @property
    def order_amount(self) -> Decimal:
        return self._order_amount

    @order_amount.setter
    def order_amount(self, value: Decimal):
        self._order_amount = value

    @property
    def order_levels(self) -> int:
        return self._order_levels

    @order_levels.setter
    def order_levels(self, value: int):
        self._order_levels = value
        self._buy_levels = value
        self._sell_levels = value

    @property
    def buy_levels(self) -> int:
        return self._buy_levels

    @buy_levels.setter
    def buy_levels(self, value: int):
        self._buy_levels = value

    @property
    def sell_levels(self) -> int:
        return self._sell_levels

    @sell_levels.setter
    def sell_levels(self, value: int):
        self._sell_levels = value

    @property
    def order_level_amount(self) -> Decimal:
        return self._order_level_amount

    @order_level_amount.setter
    def order_level_amount(self, value: Decimal):
        self._order_level_amount = value

    @property
    def order_level_spread(self) -> Decimal:
        return self._order_level_spread

    @order_level_spread.setter
    def order_level_spread(self, value: Decimal):
        self._order_level_spread = value

    @property
    def hanging_orders_enabled(self) -> bool:
        return self._hanging_orders_enabled

    @hanging_orders_enabled.setter
    def hanging_orders_enabled(self, value: bool):
        self._hanging_orders_enabled = value

    @property
    def hanging_orders_cancel_pct(self) -> Decimal:
        return self._hanging_orders_cancel_pct

    @hanging_orders_cancel_pct.setter
    def hanging_orders_cancel_pct(self, value: Decimal):
        self._hanging_orders_cancel_pct = value

    @property
    def bid_spread(self) -> Decimal:
        return self._bid_spread

    @bid_spread.setter
    def bid_spread(self, value: Decimal):
        self._bid_spread = value

    @property
    def ask_spread(self) -> Decimal:
        return self._ask_spread

    @ask_spread.setter
    def ask_spread(self, value: Decimal):
        self._ask_spread = value

    @property
    def order_optimization_enabled(self) -> bool:
        return self._order_optimization_enabled

    @order_optimization_enabled.setter
    def order_optimization_enabled(self, value: bool):
        self._order_optimization_enabled = value

    @property
    def order_refresh_time(self) -> float:
        return self._order_refresh_time

    @order_refresh_time.setter
    def order_refresh_time(self, value: float):
        self._order_refresh_time = value

    @property
    def filled_order_delay(self) -> float:
        return self._filled_order_delay

    @filled_order_delay.setter
    def filled_order_delay(self, value: float):
        self._filled_order_delay = value

    @property
    def add_transaction_costs_to_orders(self) -> bool:
        return self._add_transaction_costs_to_orders

    @add_transaction_costs_to_orders.setter
    def add_transaction_costs_to_orders(self, value: bool):
        self._add_transaction_costs_to_orders = value

    @property
    def price_ceiling(self) -> Decimal:
        return self._price_ceiling

    @price_ceiling.setter
    def price_ceiling(self, value: Decimal):
        self._price_ceiling = value

    @property
    def price_floor(self) -> Decimal:
        return self._price_floor

    @price_floor.setter
    def price_floor(self, value: Decimal):
        self._price_floor = value

    @property
    def base_asset(self):
        return self._market_info.base_asset

    @property
    def quote_asset(self):
        return self._market_info.quote_asset

    @property
    def trading_pair(self):
        return self._market_info.trading_pair

    def get_price(self) -> float:
        if self._asset_price_delegate is not None:
            price_provider = self._asset_price_delegate
        else:
            price_provider = self._market_info
        if self._price_type is PriceType.LastOwnTrade:
            price = self._last_own_trade_price
        else:
            price = price_provider.get_price_by_type(self._price_type)
        if price.is_nan():
            price = price_provider.get_price_by_type(PriceType.MidPrice)
        return price

    def get_last_price(self) -> float:
        return self._market_info.get_last_price()

    def get_mid_price(self) -> float:
        return self.c_get_mid_price()

    cdef object c_get_mid_price(self):
        cdef:
            AssetPriceDelegate delegate = self._asset_price_delegate
            object mid_price
        if self._asset_price_delegate is not None:
            mid_price = delegate.c_get_mid_price()
        else:
            mid_price = self._market_info.get_mid_price()
        return mid_price

    @property
    def hanging_order_ids(self) -> List[str]:
        return self._hanging_order_ids

    @property
    def market_info_to_active_orders(self) -> Dict[MarketTradingPairTuple, List[LimitOrder]]:
        return self._sb_order_tracker.market_pair_to_active_orders

    @property
    def active_orders(self) -> List[LimitOrder]:
        if self._market_info not in self.market_info_to_active_orders:
            return []
        return self.market_info_to_active_orders[self._market_info]

    @property
    def active_positions(self) -> List[LimitOrder]:
        return self._market_info.market.account_positions

    @property
    def active_buys(self) -> List[LimitOrder]:
        return [o for o in self.active_orders if o.is_buy]

    @property
    def active_sells(self) -> List[LimitOrder]:
        return [o for o in self.active_orders if not o.is_buy]

    @property
    def active_non_hanging_orders(self) -> List[LimitOrder]:
        orders = [o for o in self.active_orders if o.client_order_id not in self._hanging_order_ids]
        return orders

    @property
    def logging_options(self) -> int:
        return self._logging_options

    @logging_options.setter
    def logging_options(self, int64_t logging_options):
        self._logging_options = logging_options

    @property
    def asset_price_delegate(self) -> AssetPriceDelegate:
        return self._asset_price_delegate

    @asset_price_delegate.setter
    def asset_price_delegate(self, value):
        self._asset_price_delegate = value

    def perpetual_mm_assets_df(self, to_show_current_pct: bool) -> pd.DataFrame:
        market, trading_pair, base_asset, quote_asset = self._market_info
        price = self._market_info.get_mid_price()
        quote_balance = float(market.get_balance(quote_asset))
        available_quote_balance = float(market.get_available_balance(quote_asset))
        data=[
            ["", quote_asset],
            ["Total Balance", round(quote_balance, 4)],
            ["Available Balance", round(available_quote_balance, 4)]
        ]
        df = pd.DataFrame(data=data)
        return df

    def active_orders_df(self) -> pd.DataFrame:
        price = self.get_price()
        active_orders = self.active_orders
        no_sells = len([o for o in active_orders if not o.is_buy and o.client_order_id not in self._hanging_order_ids])
        active_orders.sort(key=lambda x: x.price, reverse=True)
        columns = ["Level", "Type", "Price", "Spread", "Amount (Orig)", "Amount (Adj)", "Age"]
        data = []
        lvl_buy, lvl_sell = 0, 0
        for idx in range(0, len(active_orders)):
            order = active_orders[idx]
            level = None
            if order.client_order_id not in self._hanging_order_ids:
                if order.is_buy:
                    level = lvl_buy + 1
                    lvl_buy += 1
                else:
                    level = no_sells - lvl_sell
                    lvl_sell += 1
            spread = 0 if price == 0 else abs(order.price - price)/price
            age = "n/a"
            # // indicates order is a paper order so 'n/a'. For real orders, calculate age.
            if "//" not in order.client_order_id:
                age = pd.Timestamp(int(time.time()) - int(order.client_order_id[-16:])/1e6,
                                   unit='s').strftime('%H:%M:%S')
            amount_orig = "" if level is None else self._order_amount + ((level - 1) * self._order_level_amount)
            data.append([
                "hang" if order.client_order_id in self._hanging_order_ids else level,
                "buy" if order.is_buy else "sell",
                float(order.price),
                f"{spread:.2%}",
                amount_orig,
                float(order.quantity),
                age
            ])

        return pd.DataFrame(data=data, columns=columns)

    def active_positions_df(self) -> pd.DataFrame:
        columns = ["Symbol", "Type", "Entry Price", "Amount", "Leverage", "Unrealized PnL"]
        data = []
        market, trading_pair = self._market_info.market, self._market_info.trading_pair
        for idx in self.active_positions.values():
            is_buy = True if idx.amount > 0 else False
            unrealized_profit = ((market.get_price(trading_pair, is_buy) - idx.entry_price) * idx.amount)
            data.append([
                idx.trading_pair,
                idx.position_side.name,
                idx.entry_price,
                idx.amount,
                idx.leverage,
                unrealized_profit
            ])

        return pd.DataFrame(data=data, columns=columns)

    def market_status_data_frame(self, market_trading_pair_tuples: List[MarketTradingPairTuple]) -> pd.DataFrame:
        markets_data = []
        markets_columns = ["Exchange", "Market", "Best Bid", "Best Ask", f"Ref Price ({self._price_type.name})"]
        if self._price_type is PriceType.LastOwnTrade and self._last_own_trade_price.is_nan():
            markets_columns[-1] = "Ref Price (MidPrice)"
        market_books = [(self._market_info.market, self._market_info.trading_pair)]
        if type(self._asset_price_delegate) is OrderBookAssetPriceDelegate:
            market_books.append((self._asset_price_delegate.market, self._asset_price_delegate.trading_pair))
        for market, trading_pair in market_books:
            bid_price = market.get_price(trading_pair, False)
            ask_price = market.get_price(trading_pair, True)
            ref_price = float("nan")
            if market == self._market_info.market and self._asset_price_delegate is None:
                ref_price = self.get_price()
            elif market == self._asset_price_delegate.market and self._price_type is not PriceType.LastOwnTrade:
                ref_price = self._asset_price_delegate.get_price_by_type(self._price_type)
            markets_data.append([
                market.display_name,
                trading_pair,
                float(bid_price),
                float(ask_price),
                float(ref_price)
            ])
        return pd.DataFrame(data=markets_data, columns=markets_columns).replace(np.nan, '', regex=True)

    def format_status(self) -> str:
        if not self._all_markets_ready:
            return "Market connectors are not ready."
        cdef:
            list lines = []
            list warning_lines = []
        # warning_lines.extend(self._ping_pong_warning_lines)
        # warning_lines.extend(self.network_warning([self._market_info]))

        markets_df = self.market_status_data_frame([self._market_info])
        lines.extend(["", "  Markets:"] + ["    " + line for line in markets_df.to_string(index=False).split("\n")])

        assets_df = self.perpetual_mm_assets_df(False)

        first_col_length = max(*assets_df[0].apply(len))
        df_lines = assets_df.to_string(index=False, header=False,
                                       formatters={0: ("{:<" + str(first_col_length) + "}").format}).split("\n")
        lines.extend(["", "  Assets:"] + ["    " + line for line in df_lines])

        # See if there're any open orders.
        if len(self.active_orders) > 0:
            df = self.active_orders_df()
            lines.extend(["", "  Orders:"] + ["    " + line for line in df.to_string(index=False).split("\n")])
        else:
            lines.extend(["", "  No active maker orders."])

        # See if there're any active positions.
        if len(self.active_positions) > 0:
            df = self.active_positions_df()
            lines.extend(["", "  Positions:"] + ["    " + line for line in df.to_string(index=False).split("\n")])
        else:
            lines.extend(["", "  No active positions."])

        # warning_lines.extend(self.balance_warning([self._market_info]))

        if len(warning_lines) > 0:
            lines.extend(["", "*** WARNINGS ***"] + warning_lines)

        return "\n".join(lines)

    # The following exposed Python functions are meant for unit tests
    # ---------------------------------------------------------------

    def cancel_order(self, order_id: str):
        return self.c_cancel_order(self._market_info, order_id)

    # ---------------------------------------------------------------

    cdef c_start(self, Clock clock, double timestamp):
        StrategyBase.c_start(self, clock, timestamp)
        self._last_timestamp = timestamp
        self.c_apply_initial_settings(self.trading_pair, self._position_mode, self._leverage)

    cdef c_apply_initial_settings(self, str trading_pair, object position, int64_t leverage):
        cdef:
            ExchangeBase market = self._market_info.market
        market.set_leverage(trading_pair, leverage)
        market.set_position_mode(position)

    cdef c_tick(self, double timestamp):
        StrategyBase.c_tick(self, timestamp)
        cdef:
            ExchangeBase market = self._market_info.market
            # S: TODO: BUG: active_positions is not correctly returning. There seems to be a bug -> some kind of ghost position with 0.0 amount which freezes the manage_position func
            list session_positions = [s for s in self.active_positions.values() if s.trading_pair == self.trading_pair and s.amount != 0]          
            int64_t current_tick = <int64_t>(timestamp // self._status_report_interval)
            int64_t last_tick = <int64_t>(self._last_timestamp // self._status_report_interval)
            bint should_report_warnings = ((current_tick > last_tick) and
                                           (self._logging_options & self.OPTION_LOG_STATUS_REPORT))
            cdef object proposal
        try:
            if not self._all_markets_ready:
                self._all_markets_ready = all([market.ready for market in self._sb_markets])
                if self._asset_price_delegate is not None and self._all_markets_ready:
                    self._all_markets_ready = self._asset_price_delegate.ready
                if not self._all_markets_ready:
                    # M({self.trading_pair}) Maker sell order {order_id}arkets not ready yet. Don't do anything.
                    if should_report_warnings:
                        self.logger().warning(f"Markets are not ready. No market making trades are permitted.")
                    return

            if should_report_warnings:
                if not all([market.network_status is NetworkStatus.CONNECTED for market in self._sb_markets]):
                    self.logger().warning(f"WARNING: Some markets are not connected or are down at the moment. Market "
                                          f"making may be dangerous when markets or networks are unstable.")

            # S: Capture the current tick count into a local variable to use during this tick as well as current mid price
            current_mid_price = self._market_info.get_mid_price()
            current_tick_count = self._ta.tick_count
            self._ta.tick_alert(self.logger(), current_tick_count)

            # S: Here we run candle-infrastructure and pattern detection - updates the trade-signal TODO: REMOVE logger()
            self._ta.track_and_analyze_candles(self.logger(), current_mid_price, self._current_timestamp)

            # S: Here we run trading logic derived and adapted from pmm strategy:    
            self.c_perform_trades(session_positions, self._ta.signal)

        finally:
            self._last_timestamp = timestamp

    cdef c_perform_trades(self, session_positions, current_signal):
        # S: Here we should check for a new_order_cooldown, which we set to true after every executed order proposal and set to false after every did_complete_order event with same ID
        if self._new_order_cooldown == False:
            if len(session_positions) == 0: # S: If no positions exist, make new one
                    self._exit_orders = []  # Empty list of exit order at this point to reduce size
                    proposal = None

                    debug_text = ""

                    if self._create_timestamp <= self._current_timestamp:
                        if current_signal == Signal.buy or current_signal == Signal.hold_long:
                            debug_text = "LONG PROPOSAL CREATED"
                            proposal = self.c_create_base_proposal_buy()
                        elif current_signal == Signal.sell or current_signal == Signal.hold_short:
                            debug_text = "SHORT PROPOSAL CREATED"
                            proposal = self.c_create_base_proposal_sell()
                    
                        if self.c_to_create_orders(proposal): # S: Delay happening here.

                            self.logger().info(debug_text)

                            self.c_apply_budget_constraint(proposal)
                            self._close_order_type = OrderType.MARKET # S: Is this necessary at this point?
                            self.c_execute_order_proposal(proposal, PositionAction.OPEN)

            else: # S: Else, manage those positions

                self.c_manage_positions(session_positions)

    cdef c_manage_positions(self, list session_positions):
        cdef:
            object mode = self._position_mode
            ExchangeBase market = self._market_info.market
            list buys = []
            list sells = []

        for position in session_positions:
            
            # self.logger().info(f"position amount is {position.amount}")
            
            # S: Condition to only close, if we currently have a sell signal or rather NO hold_long signal
            if position.amount > 0: # S: It is a long position -> we need to close it with a sell-order
                if self._ta.signal == Signal.sell: 
                    size = market.c_quantize_order_amount(self.trading_pair, abs(position.amount))
                    self.logger().info(f"POSITION AMOUNT in manage_positions: {position.amount}")
                    price = market.get_price(self.trading_pair, False)
                    sells.append(PriceSize(price, size)) 
            # S: Condition to only close, if we currently have a buy signal or rather NO hold_short signal
            else: # S: It is a short position -> we need to close it with a buy-order 
                if position.amount != 0: 
                    if self._ta.signal == Signal.buy: 
                        size = market.c_quantize_order_amount(self.trading_pair, abs(position.amount))
                        self.logger().info(f"POSITION AMOUNT in manage_positions: {position.amount}")
                        price = market.get_price(self.trading_pair, True)
                        buys.append(PriceSize(price, size))

        proposals = Proposal(buys, sells) 

        if proposals is not None:
            self.c_execute_order_proposal(proposals, PositionAction.CLOSE)

    cdef object c_create_base_proposal_buy(self): # S: BUG: Why do we have the wrong quote balance when opening long and short?
        cdef:
            ExchangeBase market = self._market_info.market
            # object quote_balance = market.c_get_available_balance(self.quote_asset) # S: TODO: WIP HERE DEBUGGING
            object quote_balance = self.c_get_adjusted_available_balance(self.active_orders)[1]
            list buys = []
            list sells = []

        price = market.get_price(self.trading_pair, True) # S: Correct way to set bid price (works and results in filled order aka an open position)
        
        # S: calculate amount based on user set percentage        
        user_set_volume = self._ta.trade_volume/100
        quote_amount = Decimal(quote_balance * user_set_volume)
        trade_amount = Decimal(quote_amount/price)
        size = trade_amount # self._order_amount <- S: This is the old way of setting amount (fixed amount)
        size = market.c_quantize_order_amount(self.trading_pair, size)
        self.logger().info(f"trade_volume: {self._ta.trade_volume}")
        self.logger().info(f"quote_balance: {quote_balance}")
        self.logger().info(f"quote_amount (quote_balance * trade_volume)/100: {quote_amount}")
        self.logger().info(f"SIZE TO BUY: {size}")
        if size > 0:
            buys.append(PriceSize(price, size))

        return Proposal(buys, sells)

    cdef object c_create_base_proposal_sell(self):
        cdef:
            ExchangeBase market = self._market_info.market
            # object quote_balance = market.c_get_available_balance(self.quote_asset) # S: TODO: WIP HERE DEBUGGING
            object quote_balance = self.c_get_adjusted_available_balance(self.active_orders)[1]
            list buys = []
            list sells = []

        price = market.get_price(self.trading_pair, False) # S: Correct way to set ask price (works and results in filled order aka an open position)
       
        # S: calculate amount based on user set percentage
        user_set_volume = self._ta.trade_volume/100
        quote_amount = Decimal(quote_balance * user_set_volume)
        trade_amount = Decimal(quote_amount/price)
        size = trade_amount # self._order_amount <- S: This is the old way of setting amount (fixed amount)
        size = market.c_quantize_order_amount(self.trading_pair, size)
        self.logger().info(f"trade_volume: {self._ta.trade_volume}")
        self.logger().info(f"quote_balance: {quote_balance}")
        self.logger().info(f"quote_amount (quote_balance * trade_volume)/100: {quote_amount}")
        self.logger().info(f"SIZE TO SELL: {size}")
        if size > 0:
            sells.append(PriceSize(price, size))

        return Proposal(buys, sells)

    cdef tuple c_get_adjusted_available_balance(self, list orders):
        """
        Calculates the available balance, plus the amount attributed to orders.
        :return: (USDT amount) in Decimal
        """
        cdef:
            ExchangeBase market = self._market_info.market
            # object quote_balance = self._market_info.market.c_get_available_balance(self.quote_asset)
            object quote_balance = market.c_get_available_balance(self.quote_asset)
            object base_balance = market.c_get_available_balance(self.base_asset) # S: Attention, changed this
        
        for order in orders:
            if order.is_buy:
                quote_balance += order.quantity * order.price / self._leverage
                self.logger().info(f"orderID: {order.id}, quote_balance: {quote_balance}")
            else:
                base_balance += order.quantity
        return base_balance, quote_balance

    cdef c_apply_order_levels_modifiers(self, proposal):
        self.c_apply_price_band(proposal)
        if self._ping_pong_enabled:
            self.c_apply_ping_pong(proposal)

    cdef c_apply_price_band(self, proposal):
        if self._price_ceiling > 0 and self.get_price() >= self._price_ceiling:
            proposal.buys = []
        if self._price_floor > 0 and self.get_price() <= self._price_floor:
            proposal.sells = []

    cdef c_apply_ping_pong(self, object proposal):
        self._ping_pong_warning_lines = []
        if self._filled_buys_balance == self._filled_sells_balance:
            self._filled_buys_balance = self._filled_sells_balance = 0
        if self._filled_buys_balance > 0:
            proposal.buys = proposal.buys[self._filled_buys_balance:]
            self._ping_pong_warning_lines.extend(
                [f"  Ping-pong removed {self._filled_buys_balance} buy orders."]
            )
        if self._filled_sells_balance > 0:
            proposal.sells = proposal.sells[self._filled_sells_balance:]
            self._ping_pong_warning_lines.extend(
                [f"  Ping-pong removed {self._filled_sells_balance} sell orders."]
            )

    cdef c_apply_order_price_modifiers(self, object proposal):
        if self._order_optimization_enabled:
            self.c_apply_order_optimization(proposal)

        if self._add_transaction_costs_to_orders:
            self.c_apply_add_transaction_costs(proposal)

    cdef c_apply_budget_constraint(self, object proposal):
        cdef:
            ExchangeBase market = self._market_info.market
            object quote_size
            object base_size
            object quote_size_total = Decimal("0")
            object base_size_total = Decimal("0")

        quote_balance = market.c_get_available_balance(self.quote_asset)
        trading_fees = market.c_get_fee(self.base_asset, self.quote_asset, OrderType.LIMIT, TradeType.BUY,
                                        s_decimal_zero, s_decimal_zero)

        for buy in proposal.buys:
            order_size = buy.size * buy.price
            quote_size = (order_size / self._leverage) + (order_size * trading_fees.percent)
            if quote_balance < quote_size_total + quote_size:
                self.logger().info(f"Insufficient balance: Buy order (price: {buy.price}, size: {buy.size}) is omitted, {self.quote_asset} available balance: {quote_balance - quote_size_total}.")
                self.logger().warning("You are also at a possible risk of being liquidated if there happens to be an open loss.")
                quote_size = s_decimal_zero
                buy.size = s_decimal_zero
            quote_size_total += quote_size
        proposal.buys = [o for o in proposal.buys if o.size > 0]
        for sell in proposal.sells:
            order_size = sell.size * sell.price
            quote_size = (order_size / self._leverage) + (order_size * trading_fees.percent)
            if quote_balance < quote_size_total + quote_size:
                self.logger().info(f"Insufficient balance: Sell order (price: {sell.price}, size: {sell.size}) is omitted, {self.quote_asset} available balance: {quote_balance - quote_size_total}.")
                self.logger().warning("You are also at a possible risk of being liquidated if there happens to be an open loss.")
                base_size = s_decimal_zero
                sell.size = s_decimal_zero
            quote_size_total += quote_size
        proposal.sells = [o for o in proposal.sells if o.size > 0]

    cdef c_filter_out_takers(self, object proposal):
        cdef:
            ExchangeBase market = self._market_info.market
            list new_buys = []
            list new_sells = []
        top_ask = market.c_get_price(self.trading_pair, True)
        if not top_ask.is_nan():
            proposal.buys = [buy for buy in proposal.buys if buy.price < top_ask]
        top_bid = market.c_get_price(self.trading_pair, False)
        if not top_bid.is_nan():
            proposal.sells = [sell for sell in proposal.sells if sell.price > top_bid]

    # Compare the market price with the top bid and top ask price
    cdef c_apply_order_optimization(self, object proposal):
        cdef:
            ExchangeBase market = self._market_info.market
            object own_buy_size = s_decimal_zero
            object own_sell_size = s_decimal_zero

        # If there are multiple orders, do not jump prices
        if self._order_levels > 1:
            return

        for order in self.active_orders:
            if order.is_buy:
                own_buy_size = order.quantity
            else:
                own_sell_size = order.quantity

        if len(proposal.buys) == 1:
            # Get the top bid price in the market using order_optimization_depth and your buy order volume
            top_bid_price = self._market_info.get_price_for_volume(
                False, self._bid_order_optimization_depth + own_buy_size).result_price
            price_quantum = market.c_get_order_price_quantum(
                self.trading_pair,
                top_bid_price
            )
            # Get the price above the top bid
            price_above_bid = (ceil(top_bid_price / price_quantum) + 1) * price_quantum

            # If the price_above_bid is lower than the price suggested by the pricing proposal,
            # lower your price to this
            lower_buy_price = min(proposal.buys[0].price, price_above_bid)
            proposal.buys[0].price = market.c_quantize_order_price(self.trading_pair, lower_buy_price)

        if len(proposal.sells) == 1:
            # Get the top ask price in the market using order_optimization_depth and your sell order volume
            top_ask_price = self._market_info.get_price_for_volume(
                True, self._ask_order_optimization_depth + own_sell_size).result_price
            price_quantum = market.c_get_order_price_quantum(
                self.trading_pair,
                top_ask_price
            )
            # Get the price below the top ask
            price_below_ask = (floor(top_ask_price / price_quantum) - 1) * price_quantum

            # If the price_below_ask is higher than the price suggested by the pricing proposal,
            # increase your price to this
            higher_sell_price = max(proposal.sells[0].price, price_below_ask)
            proposal.sells[0].price = market.c_quantize_order_price(self.trading_pair, higher_sell_price)

    cdef object c_apply_add_transaction_costs(self, object proposal):
        cdef:
            ExchangeBase market = self._market_info.market
        for buy in proposal.buys:
            fee = market.c_get_fee(self.base_asset, self.quote_asset,
                                   OrderType.LIMIT, TradeType.BUY, buy.size, buy.price)
            price = buy.price * (Decimal(1) - fee.percent)
            buy.price = market.c_quantize_order_price(self.trading_pair, price)
        for sell in proposal.sells:
            fee = market.c_get_fee(self.base_asset, self.quote_asset,
                                   OrderType.LIMIT, TradeType.SELL, sell.size, sell.price)
            price = sell.price * (Decimal(1) + fee.percent)
            sell.price = market.c_quantize_order_price(self.trading_pair, price)

    cdef c_did_fill_order(self, object order_filled_event):
        cdef:
            str order_id = order_filled_event.order_id
            object market_info = self._sb_order_tracker.c_get_shadow_market_pair_from_order_id(order_id)
            tuple order_fill_record

        if market_info is not None:
            limit_order_record = self._sb_order_tracker.c_get_shadow_limit_order(order_id)
            order_fill_record = (limit_order_record, order_filled_event)

            if order_filled_event.trade_type is TradeType.BUY:
                if self._logging_options & self.OPTION_LOG_MAKER_ORDER_FILLED:
                    self.log_with_clock(
                        logging.INFO,
                        f"({market_info.trading_pair}) Maker buy order of "
                        f"{order_filled_event.amount} {market_info.base_asset} filled."
                    )
            else:
                if self._logging_options & self.OPTION_LOG_MAKER_ORDER_FILLED:
                    self.log_with_clock(
                        logging.INFO,
                        f"({market_info.trading_pair}) Maker sell order of "
                        f"{order_filled_event.amount} {market_info.base_asset} filled."
                    )

    cdef c_did_complete_buy_order(self, object order_completed_event):
        cdef:
            str order_id = order_completed_event.order_id
            limit_order_record = self._sb_order_tracker.c_get_limit_order(self._market_info, order_id)

        self.logger().info(f"CURRENTLY BEING PROCESSED ORDER IS: {self._currently_processed_order_id} - WE JUST DID COMPLETE BUY ORDER {order_id}")
        
        # S: Cooldown for new orders has passed, since this order is now finished - needs to happen in a did cancel call back as well...right?
        if order_id == self._currently_processed_order_id:
            self._new_order_cooldown = False
        
        # S: Delay such that we only submit Proposals with correct amount (querrying quote_balance too early results in wrong values)
        self._create_timestamp = self._current_timestamp + self._filled_order_delay 
        self._cancel_timestamp = min(self._cancel_timestamp, self._create_timestamp)

    cdef c_did_complete_sell_order(self, object order_completed_event):
        cdef:
            str order_id = order_completed_event.order_id
            LimitOrder limit_order_record = self._sb_order_tracker.c_get_limit_order(self._market_info, order_id)

        self.logger().info(f"CURRENTLY BEING PROCESSED ORDER IS: {self._currently_processed_order_id} - WE JUST DID COMPLETE SELL ORDER {order_id}")

         # S: Cooldown for new orders has passed, since this order is now finished - needs to happen in a did cancel call back as well...right?
        if order_id == self._currently_processed_order_id:
            self._new_order_cooldown = False

        # S: Delay such that we only submit Proposals with correct amount (querrying quote_balance too early results in wrong values)
        self._create_timestamp = self._current_timestamp + self._filled_order_delay 
        self._cancel_timestamp = min(self._cancel_timestamp, self._create_timestamp)
    
    cdef c_did_fail_order(self, object order_failed_event):
        cdef:
            str order_id = order_failed_event.order_id
            LimitOrder limit_order_record = self._sb_order_tracker.c_get_limit_order(self._market_info, order_id)
        
        # S: Cooldown for new orders has passed, since this order is now finished - needs to happen in a did cancel call back as well...right?
        if order_id == self._currently_processed_order_id:
            self._new_order_cooldown = False
    
    cdef c_did_cancel_order(self, object cancelled_event):
        cdef:
            str order_id = cancelled_event.order_id
            LimitOrder limit_order_record = self._sb_order_tracker.c_get_limit_order(self._market_info, order_id)
        
        # S: Cooldown for new orders has passed, since this order is now finished - needs to happen in a did cancel call back as well...right?
        if order_id == self._currently_processed_order_id:
            self._new_order_cooldown = False
    
    cdef c_did_expire_order(self, object expired_event):
        cdef:
            str order_id = expired_event.order_id
            LimitOrder limit_order_record = self._sb_order_tracker.c_get_limit_order(self._market_info, order_id)
        
        # S: Cooldown for new orders has passed, since this order is now finished - needs to happen in a did cancel call back as well...right?
        if order_id == self._currently_processed_order_id:
            self._new_order_cooldown = False

    cdef bint c_to_create_orders(self, object proposal):
        return self._create_timestamp < self._current_timestamp and \
            proposal is not None and \
            len(self.active_non_hanging_orders) == 0

    cdef c_execute_order_proposal(self, object proposal, object position_action):
        cdef:
            double expiration_seconds = NaN
            str bid_order_id, ask_order_id
            bint orders_created = False
            object order_type = self._close_order_type

        if len(proposal.buys) > 0: 
            if position_action == PositionAction.CLOSE:
                # S: Here we close an open SHORT position

                if self._logging_options & self.OPTION_LOG_CREATE_ORDER:
                    price_quote_str = [f"{buy.size.normalize()} {self.base_asset}, "
                                    f"{buy.price.normalize()} {self.quote_asset}"
                                    for buy in proposal.buys]
                    self.logger().info(
                        f"({self.trading_pair}) Creating {len(proposal.buys)} {self._close_order_type.name} bid orders "
                        f"at (Size, Price): {price_quote_str} to {position_action.name} position."
                    )
                
                for buy in proposal.buys:
                    
                    # market = self._market_info.market

                    bid_order_id = self.c_buy_with_specific_market(
                        self._market_info,
                        buy.size,
                        order_type=order_type,
                        price=buy.price, 
                        expiration_seconds=expiration_seconds,
                        position_action=position_action
                    )

                    self._currently_processed_order_id = bid_order_id
                    self._new_order_cooldown = True
                    
                    # S: TODO: Try out, if we even need this if block
                    if position_action == PositionAction.CLOSE:
                        self._exit_orders.append(bid_order_id)

                    orders_created = True

            else: # S: Here we open a new LONG Position BUG: Why do we have the wrong quote balance when opening long?
                if self._logging_options & self.OPTION_LOG_CREATE_ORDER:
                    price_quote_str = [f"{buy.size.normalize()} {self.base_asset}, "
                                    f"{buy.price.normalize()} {self.quote_asset}"
                                    for buy in proposal.buys]
                    self.logger().info(
                        f"({self.trading_pair}) Creating {len(proposal.buys)} {self._close_order_type.name} bid orders "
                        f"at (Size, Price): {price_quote_str} to {position_action.name} position."
                    )
                
                for buy in proposal.buys: 

                    # market = self._market_info.market

                    bid_order_id = self.c_buy_with_specific_market(
                        self._market_info,
                        buy.size,
                        order_type=order_type,
                        price=buy.price, 
                        expiration_seconds=expiration_seconds,
                        position_action=position_action
                    )

                    self._currently_processed_order_id = bid_order_id
                    self._new_order_cooldown = True

                    # S: TODO: Try out, if we even need this if block
                    if position_action == PositionAction.CLOSE:
                        self._exit_orders.append(bid_order_id)

                    orders_created = True

        if len(proposal.sells) > 0:
            if position_action == PositionAction.CLOSE:
                # S: Here we close an open LONG position

                self.logger().info("Here we would close the LONG position")

                if self._logging_options & self.OPTION_LOG_CREATE_ORDER:
                    price_quote_str = [f"{sell.size.normalize()} {self.base_asset}, "
                                    f"{sell.price.normalize()} {self.quote_asset}"
                                    for sell in proposal.sells]
                    self.logger().info(
                        f"({self.trading_pair}) Creating {len(proposal.sells)}  {self._close_order_type.name} ask "
                        f"orders at (Size, Price): {price_quote_str} to {position_action.name} position."
                    )
                for sell in proposal.sells:
                    
                    # market = self._market_info.market

                    ask_order_id = self.c_sell_with_specific_market(
                        self._market_info,
                        sell.size,
                        order_type=order_type,
                        price=sell.price,
                        expiration_seconds=expiration_seconds,
                        position_action=position_action
                    )

                    self._currently_processed_order_id = ask_order_id
                    self._new_order_cooldown = True
                   
                    # S: TODO: Try out, if we even need this if block
                    if position_action == PositionAction.CLOSE:
                        self._exit_orders.append(ask_order_id)

                    orders_created = True 

            else: # S: Here we open a new SHORT Position
                if self._logging_options & self.OPTION_LOG_CREATE_ORDER:
                    price_quote_str = [f"{sell.size.normalize()} {self.base_asset}, "
                                    f"{sell.price.normalize()} {self.quote_asset}"
                                    for sell in proposal.sells]
                    self.logger().info(
                        f"({self.trading_pair}) Creating {len(proposal.sells)}  {self._close_order_type.name} ask "
                        f"orders at (Size, Price): {price_quote_str} to {position_action.name} position."
                    )
                for sell in proposal.sells:
                    ask_order_id = self.c_sell_with_specific_market(
                        self._market_info,
                        sell.size,
                        order_type=order_type,
                        price=sell.price,
                        expiration_seconds=expiration_seconds,
                        position_action=position_action
                    )

                    self._currently_processed_order_id = ask_order_id
                    self._new_order_cooldown = True

                    # S: TODO: Try out, if we even need this if block
                    if position_action == PositionAction.CLOSE:
                        self._exit_orders.append(ask_order_id)
                        self.logger().inf(f"WHY did we get here? (in OPENING SHORT BLOCK) - actual action: {position_action}")
                    orders_created = True        

    cdef set_timers(self):
        cdef double next_cycle = self._current_timestamp + self._order_refresh_time
        if self._create_timestamp <= self._current_timestamp:
            self._create_timestamp = next_cycle
        if self._cancel_timestamp <= self._current_timestamp:
            self._cancel_timestamp = min(self._create_timestamp, next_cycle)

    def notify_hb_app(self, msg: str):
        if self._hb_app_notification:
            super().notify_hb_app(msg)

    def get_price_type(self, price_type_str: str) -> PriceType:
        if price_type_str == "mid_price": # S: average between bid and ask
            return PriceType.MidPrice
        elif price_type_str == "best_bid": # S: best price I (as buyer) want to pay
            return PriceType.BestBid
        elif price_type_str == "best_ask": # S: best price I (as seller) want to offer
            return PriceType.BestAsk
        elif price_type_str == "last_price":
            return PriceType.LastTrade
        elif price_type_str == 'last_own_trade_price':
            return PriceType.LastOwnTrade
        else:
            raise ValueError(f"Unrecognized price type string {price_type_str}.")
