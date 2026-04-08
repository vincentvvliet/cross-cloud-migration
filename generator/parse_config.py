import yaml
from capabilities import Delivery, Consistency
from pathlib import Path

CONFIG_ROOT = Path("config")


def parse_config(path="config/compiled.yaml"):
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


def load_yaml(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Missing config file: {path}")
    with open(path, "r") as f:
        return yaml.safe_load(f)


def resolve_system_config(system_type: str, system_name: str) -> dict:
    """
    Example:
        system_type = "queue"
        system_name = "BaseQueue"

    Will load:
        config/queue/baseQueue.yaml
    """
    file_name = f"{system_name[0].lower()}{system_name[1:]}.yaml"
    system_path = CONFIG_ROOT / system_type / file_name

    config = load_yaml(system_path)

    return config


def compile_config() -> dict:
    base_config_path = CONFIG_ROOT / "config.yaml"
    base_config = load_yaml(base_config_path)

    compiled = {}

    # Copy composition as-is
    compiled["composition"] = base_config["composition"]

    compiled["systems"] = {}

    for system_type, system_name in base_config["systems"].items():
        system_config = resolve_system_config(system_type, system_name)

        compiled["systems"][system_type] = {"type": system_name, **system_config}

    return compiled


def load_compat_config(path="config/compat.yaml"):
    """
    Load a compatibility config with:
    source: { systems: ..., composition: ... }
    target: { systems: ..., composition: ... }

    Returns:
        (source_caps, target_caps)
    """

    raw = load_yaml(Path(path))

    def build_caps(section):
        compiled = {}

        compiled["composition"] = raw[section]["composition"]
        compiled["systems"] = {}

        for system_type, system_name in raw[section]["systems"].items():
            system_config = resolve_system_config(system_type, system_name)

            compiled["systems"][system_type] = {
                "type": system_name,
                **system_config,
            }

        return parse_config_dict(compiled)

    return build_caps("source"), build_caps("target")


def parse_config_dict(data: dict):
    """Same as parse_config but operates on dict instead of file."""
    for s in data["systems"].values():
        if "delivery" in s:
            s["delivery"] = map_delivery(s["delivery"])
        if "consistency" in s:
            s["consistency"] = map_consistency(s["consistency"])

    return data


def load_config():
    compiled = compile_config()

    output_path = CONFIG_ROOT / "compiled.yaml"

    with open(output_path, "w") as f:
        yaml.dump(compiled, f, sort_keys=False)

    print(f"Compiled configuration written to {output_path}")

    return parse_config()


if __name__ == "__main__":
    load_config()
