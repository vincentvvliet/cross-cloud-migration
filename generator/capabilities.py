from dataclasses import dataclass
from enum import IntEnum, Enum


class Delivery(IntEnum):
    AT_MOST_ONCE = 0
    AT_LEAST_ONCE = 1
    EXACTLY_ONCE = 2

    @staticmethod
    def from_str(s: str) -> "Delivery":
        return {
            "at_most_once": Delivery.AT_MOST_ONCE,
            "at_least_once": Delivery.AT_LEAST_ONCE,
            "exactly_once": Delivery.EXACTLY_ONCE,
        }[s]


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
