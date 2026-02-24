from dataclasses import dataclass
from typing import Callable


@dataclass
class Signature:
    args: str
    call: Callable[[str], str]


SIGNATURES = {
    "msg": Signature(
        args="m: Message",
        call=lambda name: f"{name}(m)",
    ),
    "msg_replica": Signature(
        args="m: Message, r: Replica",
        call=lambda name: f"{name}(m, r)",
    ),
    "sync": Signature(
        args="r1: Replica, r2: Replica",
        call=lambda name: f"{name}(r1, r2)",
    ),
    "crash": Signature(
        args="",
        call=lambda name: f"{name}",
    ),
}
