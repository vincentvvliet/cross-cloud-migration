import yaml
from capabilities import *

def parse_config(path: str) -> SystemCaps:
    with open(path) as f:
        data = yaml.safe_load(f)

    queue = QueueCaps(
        delivery=Delivery(data["queue"]["delivery"]),
        max_size=data["queue"]["max_size"]
    )

    kv = KVCaps(
        consistency=Consistency(data["kv"]["consistency"]),
        conditional_writes=data["kv"]["conditional_writes"],
        idempotent_writes=data["kv"]["idempotent_writes"],
        max_size=data["kv"]["max_size"]
    )

    return SystemCaps(queue=queue, kv=kv)
