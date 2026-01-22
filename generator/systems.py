import json


def load_systems(path="config/systems.json"):
    """Load the systems database from a JSON file."""
    with open(path) as f:
        return json.load(f)
