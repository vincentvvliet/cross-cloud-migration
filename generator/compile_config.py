import yaml
from pathlib import Path

CONFIG_ROOT = Path("config")


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


def main():
    compiled = compile_config()

    output_path = CONFIG_ROOT / "compiled.yaml"

    with open(output_path, "w") as f:
        yaml.dump(compiled, f, sort_keys=False)

    print(f"Compiled configuration written to {output_path}")


if __name__ == "__main__":
    main()
