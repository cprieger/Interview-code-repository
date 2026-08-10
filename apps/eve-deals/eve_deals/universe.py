"""Station/system/region/name resolution, backed by the sqlite universe_cache table."""

from eve_deals import db, esi_client


def system_name_to_id(name):
    cached = db.cache_get("name_id", name.lower())
    if cached:
        return int(cached)

    results = esi_client.resolve_names_to_ids([name])
    systems = results.get("systems") or []
    if not systems:
        return None

    system_id = systems[0]["id"]
    db.cache_set("name_id", name.lower(), system_id)
    return system_id


def system_id_to_region_id(system_id):
    cached = db.cache_get("system_region", system_id)
    if cached:
        return int(cached)

    system = esi_client.get_system(system_id)
    constellation = esi_client.get_constellation(system["constellation_id"])
    region_id = constellation["region_id"]
    db.cache_set("system_region", system_id, region_id)
    return region_id


def system_id_to_name(system_id):
    cached = db.cache_get("system_id_name", system_id)
    if cached:
        return cached

    system = esi_client.get_system(system_id)
    name = system["name"]
    db.cache_set("system_id_name", system_id, name)
    return name


def location_id_to_system_id(location_id, access_token):
    """Resolve a contract's start_location_id (station or structure) to a system_id.

    Returns None if it can't be resolved (e.g. an inaccessible player structure).
    """
    cached = db.cache_get("station_system", location_id)
    if cached:
        return int(cached)

    # NPC station IDs are < 1,000,000,000; anything higher is a player structure.
    if location_id < 1_000_000_000:
        station = esi_client.get_station(location_id)
        if not station:
            return None
        system_id = station["system_id"]
    else:
        structure = esi_client.get_structure(location_id, access_token)
        if not structure:
            return None
        system_id = structure["solar_system_id"]

    db.cache_set("station_system", location_id, system_id)
    return system_id
