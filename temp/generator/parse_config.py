import yaml

def parse_config(path="config/config.yaml"):
    with open(path) as f:
        return yaml.safe_load(f)
