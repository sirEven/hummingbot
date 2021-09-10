from typing import Optional, List

def weighted_ma(series: List[float], period: Optional[int] = None) -> float:
    if not period:
        period = len(series)
    if len(series) == 0:
        return 0
    assert 0 < period <= len(series)

    wma = 0
    period_offset = len(series) - period
    for index in range(period + period_offset - 1, period_offset - 1, -1):
        weight = index - period_offset + 1
        wma += series[index] * weight
    return wma / ((period ** 2 + period) / 2)

def hull_ma(series: List[float], period: int) -> float:
    assert period > 0
    hma_series = []
    for k in range(int(period ** 0.5), -1, -1):
        s = series[:-k or None]
        wma_half = weighted_ma(s, min(period // 2, len(s)))
        wma_full = weighted_ma(s, min(period, len(s)))
        hma_series.append(wma_half * 2 - wma_full)
    return weighted_ma(hma_series) # S: Note: We ommit the second parameter (which in other hullMA algos is square root of period)