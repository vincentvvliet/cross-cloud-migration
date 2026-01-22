import yaml
from capabilities import Delivery, Consistency


def parse_config(path="config/config.yaml"):
    """Parse the configuration YAML file and map delivery strings to enum values."""
    with open(path) as f:

        data = yaml.safe_load(f)
        for s in data["systems"].values():
            if "delivery" in s:
                s["delivery"] = map_delivery(s["delivery"])
            if "consistency" in s:
                s["consistency"] = map_consistency(s["consistency"])

        return data


def map_delivery(s: str) -> int:
    """Map delivery string to Delivery enum value."""
    return Delivery.from_str(s).value


def map_consistency(s: str) -> int:
    """Map delivery string to Delivery enum value."""
    return Consistency.from_str(s).value


if __name__ == "__main__":
    config = parse_config()
