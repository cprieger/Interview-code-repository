"""Fair-value pricing: trim outlier high/low market prices before averaging.

Rule: drop the single highest and single lowest price in the sample, unless
there's only one price total (nothing to trim). This keeps one junk listing
(way overpriced or a fat-fingered giveaway) from skewing the reference price.
"""

from eve_deals import esi_client


def trimmed_mean(prices):
    if not prices:
        return None
    if len(prices) == 1:
        return prices[0]

    ordered = sorted(prices)
    trimmed = ordered[1:-1]
    if not trimmed:
        # Exactly two prices: nothing left after trimming both ends, fall back
        # to their average rather than discarding the data entirely.
        return sum(ordered) / len(ordered)

    return sum(trimmed) / len(trimmed)


def fair_unit_price(region_id, type_id):
    orders = esi_client.get_market_sell_orders(region_id, type_id)
    prices = [order["price"] for order in orders]
    return trimmed_mean(prices)


def evaluate_contract(region_id, contract, items):
    """Returns (fair_value, discount_pct, item_summary) or None if unpriceable."""
    total_fair_value = 0.0
    summary_parts = []
    priced_any = False

    for item in items:
        quantity = item.get("quantity", 1)
        unit_price = fair_unit_price(region_id, item["type_id"])
        if unit_price is None:
            summary_parts.append(f"type {item['type_id']} x{quantity} (unpriced)")
            continue
        priced_any = True
        total_fair_value += unit_price * quantity
        summary_parts.append(f"type {item['type_id']} x{quantity} @ {unit_price:,.0f}")

    if not priced_any or total_fair_value <= 0:
        return None

    price = contract.get("price") or 0.0
    discount_pct = ((total_fair_value - price) / total_fair_value) * 100

    return total_fair_value, discount_pct, "; ".join(summary_parts)
