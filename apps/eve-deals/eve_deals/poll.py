"""Orchestrates one 'Poll' run: locate character, resolve regions, scan contracts, price them."""

import time

from eve_deals import db, esi_client, pricing, universe
from eve_deals.config import DEAL_DISCOUNT_THRESHOLD_PCT


def _scan_system(system_id, access_token, polled_at):
    system_name = universe.system_id_to_name(system_id)
    region_id = universe.system_id_to_region_id(system_id)
    contracts = esi_client.get_all_public_contracts(region_id)

    found = []
    for contract in contracts:
        if contract.get("type") != "item_exchange":
            continue

        start_location_id = contract.get("start_location_id")
        if start_location_id is None:
            continue

        contract_system_id = universe.location_id_to_system_id(start_location_id, access_token)
        if contract_system_id != system_id:
            continue

        items = esi_client.get_public_contract_items(contract["contract_id"])
        if not items:
            continue

        result = pricing.evaluate_contract(region_id, contract, items)
        if result is None:
            continue

        fair_value, discount_pct, item_summary = result
        if discount_pct < DEAL_DISCOUNT_THRESHOLD_PCT:
            continue

        deal = {
            "contract_id": contract["contract_id"],
            "system_id": system_id,
            "system_name": system_name,
            "title": contract.get("title") or "(untitled)",
            "price": contract.get("price"),
            "fair_value": round(fair_value, 2),
            "discount_pct": round(discount_pct, 1),
            "item_summary": item_summary,
        }
        db.save_deal(polled_at, **deal)
        found.append(deal)

    return found


def run_poll(home_system_id, reference_system_name, access_token):
    polled_at = time.time()

    reference_system_id = universe.system_name_to_id(reference_system_name)
    if reference_system_id is None:
        raise ValueError(f"Could not resolve system name: {reference_system_name!r}")

    deals = []
    deals.extend(_scan_system(home_system_id, access_token, polled_at))
    if reference_system_id != home_system_id:
        deals.extend(_scan_system(reference_system_id, access_token, polled_at))

    deals.sort(key=lambda d: d["discount_pct"], reverse=True)
    return polled_at, deals
