import yaml
from capabilities import Delivery

def parse_config(path="config/config.yaml"):
    with open(path) as f:
        
        data = yaml.safe_load(f)
        for s in data['systems'].values():
            if 'delivery' in s:
                s['delivery'] = map_delivery(s['delivery'])

        return data

def map_delivery(s: str) -> int:
    return Delivery.from_str(s).value

if __name__ == "__main__":
    config = parse_config()
    print(config)