"""Thin wrapper around the public/authenticated ESI HTTP endpoints we need."""

import requests

from eve_deals.config import ESI_BASE_URL

_TIMEOUT = 15


def _auth_headers(access_token):
    return {"Authorization": f"Bearer {access_token}"} if access_token else {}


def get_character_location(character_id, access_token):
    resp = requests.get(
        f"{ESI_BASE_URL}/characters/{character_id}/location/",
        headers=_auth_headers(access_token),
        timeout=_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()["solar_system_id"]


def get_system(system_id):
    resp = requests.get(f"{ESI_BASE_URL}/universe/systems/{system_id}/", timeout=_TIMEOUT)
    resp.raise_for_status()
    return resp.json()


def get_constellation(constellation_id):
    resp = requests.get(f"{ESI_BASE_URL}/universe/constellations/{constellation_id}/", timeout=_TIMEOUT)
    resp.raise_for_status()
    return resp.json()


def get_station(station_id):
    resp = requests.get(f"{ESI_BASE_URL}/universe/stations/{station_id}/", timeout=_TIMEOUT)
    if resp.status_code == 404:
        return None
    resp.raise_for_status()
    return resp.json()


def get_structure(structure_id, access_token):
    """Player citadels require a bearer token to resolve. Returns None if inaccessible."""
    resp = requests.get(
        f"{ESI_BASE_URL}/universe/structures/{structure_id}/",
        headers=_auth_headers(access_token),
        timeout=_TIMEOUT,
    )
    if resp.status_code in (403, 404):
        return None
    resp.raise_for_status()
    return resp.json()


def resolve_names_to_ids(names):
    """POST /universe/ids/ -- exact name match lookup, e.g. system names."""
    resp = requests.post(f"{ESI_BASE_URL}/universe/ids/", json=names, timeout=_TIMEOUT)
    resp.raise_for_status()
    return resp.json()


def get_public_contracts_page(region_id, page=1):
    resp = requests.get(
        f"{ESI_BASE_URL}/contracts/public/{region_id}/",
        params={"page": page},
        timeout=_TIMEOUT,
    )
    resp.raise_for_status()
    total_pages = int(resp.headers.get("X-Pages", 1))
    return resp.json(), total_pages


def get_all_public_contracts(region_id):
    contracts, total_pages = get_public_contracts_page(region_id, page=1)
    for page in range(2, total_pages + 1):
        more, _ = get_public_contracts_page(region_id, page=page)
        contracts.extend(more)
    return contracts


def get_public_contract_items(contract_id):
    resp = requests.get(f"{ESI_BASE_URL}/contracts/public/items/{contract_id}/", timeout=_TIMEOUT)
    if resp.status_code == 404:
        return []
    resp.raise_for_status()
    return resp.json()


def get_market_sell_orders(region_id, type_id):
    resp = requests.get(
        f"{ESI_BASE_URL}/markets/{region_id}/orders/",
        params={"order_type": "sell", "type_id": type_id},
        timeout=_TIMEOUT,
    )
    if resp.status_code == 404:
        return []
    resp.raise_for_status()
    return resp.json()
