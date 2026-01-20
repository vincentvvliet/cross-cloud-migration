import json

def load_systems(path="config/systems.json"):
    with open(path) as f:
        return json.load(f)
