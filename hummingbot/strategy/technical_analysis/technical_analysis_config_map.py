from decimal import Decimal

from hummingbot.client.config.config_var import ConfigVar
from hummingbot.client.config.config_validators import (
    validate_exchange,
    validate_derivative,
    validate_market_trading_pair,
    validate_bool,
    validate_decimal,
    validate_int
)
from hummingbot.client.settings import (
    required_exchanges,
    EXAMPLE_PAIRS,
)

from hummingbot.client.config.config_helpers import (
    minimum_order_amount,
    parse_cvar_value
)
from typing import Optional


def maker_trading_pair_prompt():
    derivative = technical_analysis_config_map.get("derivative").value
    example = EXAMPLE_PAIRS.get(derivative)
    return "Enter the token trading pair you would like to trade on %s%s >>> " \
           % (derivative, f" (e.g. {example})" if example else "")


# strategy specific validators
def validate_derivative_trading_pair(value: str) -> Optional[str]:
    derivative = technical_analysis_config_map.get("derivative").value
    return validate_market_trading_pair(derivative, value)


def validate_derivative_position_mode(value: str) -> Optional[str]:
    if value not in ["One-way", "Hedge"]:
        return "Position mode can either be One-way or Hedge mode"


async def order_amount_prompt() -> str:
    derivative = technical_analysis_config_map["derivative"].value
    trading_pair = technical_analysis_config_map["market"].value
    base_asset, quote_asset = trading_pair.split("-")
    min_amount = await minimum_order_amount(derivative, trading_pair)
    return f"What is the amount of {base_asset} per order? (minimum {min_amount}) >>> "


async def validate_order_amount(value: str) -> Optional[str]:
    try:
        derivative = technical_analysis_config_map["derivative"].value
        trading_pair = technical_analysis_config_map["market"].value
        min_amount = await minimum_order_amount(derivative, trading_pair)
        if Decimal(value) < min_amount:
            return f"Order amount must be at least {min_amount}."
    except Exception:
        return "Invalid order amount."


def validate_price_source(value: str) -> Optional[str]:
    if value not in {"current_market", "external_market", "custom_api"}:
        return "Invalid price source type."


def on_validate_price_source(value: str):
    if value != "external_market":
        technical_analysis_config_map["price_source_derivative"].value = None
        technical_analysis_config_map["price_source_market"].value = None
        technical_analysis_config_map["take_if_crossed"].value = None
    if value != "custom_api":
        technical_analysis_config_map["price_source_custom_api"].value = None
    else:
        technical_analysis_config_map["price_type"].value = None


def price_source_market_prompt() -> str:
    external_market = technical_analysis_config_map.get("price_source_derivative").value
    return f'Enter the token trading pair on {external_market} >>> '


def validate_price_source_derivative(value: str) -> Optional[str]:
    if value == technical_analysis_config_map.get("derivative").value:
        return "Price source derivative cannot be the same as maker derivative."
    if validate_derivative(value) is not None and validate_exchange(value) is not None:
        return "Price must must be a valid exchange or derivative connector."


def on_validated_price_source_derivative(value: str):
    if value is None:
        technical_analysis_config_map["price_source_market"].value = None


def validate_price_source_market(value: str) -> Optional[str]:
    market = technical_analysis_config_map.get("price_source_derivative").value
    return validate_market_trading_pair(market, value)


def validate_price_floor_ceiling(value: str) -> Optional[str]:
    try:
        decimal_value = Decimal(value)
    except Exception:
        return f"{value} is not in decimal format."
    if not (decimal_value == Decimal("-1") or decimal_value > Decimal("0")):
        return "Value must be more than 0 or -1 to disable this feature."


def validate_take_if_crossed(value: str) -> Optional[str]:
    err_msg = validate_bool(value)
    if err_msg is not None:
        return err_msg
    price_source_enabled = technical_analysis_config_map["price_source_enabled"].value
    take_if_crossed = parse_cvar_value(technical_analysis_config_map["take_if_crossed"], value)
    if take_if_crossed and not price_source_enabled:
        return "You can enable this feature only when external pricing source for mid-market price is used."


def derivative_on_validated(value: str):
    required_exchanges.append(value)


technical_analysis_config_map = {
    "strategy":
        ConfigVar(key="strategy",
                  prompt=None,
                  default="technical_analysis"),
    "derivative":
        ConfigVar(key="derivative",
                  prompt="Enter your maker derivative connector >>> ",
                  validator=validate_derivative,
                  on_validated=derivative_on_validated,
                  prompt_on_new=True),
    "market":
        ConfigVar(key="market",
                  prompt=maker_trading_pair_prompt,
                  validator=validate_derivative_trading_pair,
                  prompt_on_new=True),
    "order_amount":
        ConfigVar(key="order_amount",
                  prompt=order_amount_prompt,
                  type_str="decimal",
                  validator=validate_order_amount,
                  prompt_on_new=True),
    "ta_pattern":
        ConfigVar(key="ta_pattern",
                  prompt="Which TA-Pattern do you want your bot to base its decisions on? >>> ",
                  default="hullMA",
                  type_str="str",
                #   validator=lambda s: None if s in {"hullMA"} else # S: In these brackets we can add further TA-Patterns
                #   "This pattern for technical analysis is not yet implemented.",
                  prompt_on_new=True),
    "time_resolution":
        ConfigVar(key="time_resolution",
                  prompt="What time resolution should your bot observe to find the pattern? In other words: What's the duration of each candle (in seconds)? >>> ",
                  type_str="int",
                  validator=lambda v: validate_int(v, min_value=30, inclusive=True), 
                  default=30,
                  prompt_on_new=True),
    "period":
        ConfigVar(key="period",
                  prompt="What period should the pattern be based on? In other words: How many candles should the processed MA include? >>> ",
                  type_str="int",
                  validator=lambda v: validate_int(v, min_value=2, inclusive=False),
                  default=5,
                  prompt_on_new=True),
    "candle_part":
        ConfigVar(key="candle_part",
                  prompt="Which candle part do you want to observe? >>> ",
                  default="close",
                  type_str="str",
                  validator=lambda s: None if s in {"open", "high", "low", "close"} else 
                  "Invalid candle part.",
                  prompt_on_new=True),
    "trade_volume":
        ConfigVar(key="trade_volume",
                  prompt="How much of your available base currency (e.g.: 20%) do you wish to be used per trade? (This affects leverage) >>> ",
                  type_str="decimal",
                  validator=lambda v: validate_decimal(v, 1, 100, inclusive=False),
                  default=Decimal("12"),
                  prompt_on_new=True)
}
