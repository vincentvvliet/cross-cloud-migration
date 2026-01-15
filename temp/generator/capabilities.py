from dataclasses import dataclass
from enum import Enum

class Delivery(Enum):
    AT_MOST_ONCE = "at_most_once"
    AT_LEAST_ONCE = "at_least_once"
    EXACTLY_ONCE = "exactly_once"

class Consistency(Enum):
    STRONG = "strong"
    EVENTUAL = "eventual"

@dataclass
class QueueCaps:
    delivery: Delivery
    max_size: int

@dataclass
class KVCaps:
    consistency: Consistency
    conditional_writes: bool
    idempotent_writes: bool
    max_size: int

@dataclass
class SystemCaps:
    queue: QueueCaps
    kv: KVCaps
