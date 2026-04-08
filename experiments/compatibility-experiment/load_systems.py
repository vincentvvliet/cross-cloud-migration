import json


def load_systems(path="config/systems.json"):
    """Load the systems database from a JSON file."""
    with open(path) as f:
        return json.load(f)


def import_systems():
    systems_db = load_systems("config/systems.json")

    QUEUE_SYSTEMS = [s for s in systems_db if systems_db[s]["type"].startswith("queue")]
    KV_SYSTEMS = [s for s in systems_db if systems_db[s]["type"] == "kv"]
    return systems_db, QUEUE_SYSTEMS, KV_SYSTEMS
