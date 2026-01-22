from typing import Callable
from capabilities import SystemCaps, Delivery, Consistency
from dataclasses import dataclass
from typing import Any
from enum import IntEnum


@dataclass
class Invariant:
    name: str
    requires: dict[str, Any]
    quint: str


def satisfies(caps: SystemCaps, requires: dict[str, Any]) -> bool:
    """
    Determines whether system capabilities match required capabilities for invariant
    """
    for path, required in requires.items():
        obj = caps
        for part in path.split("."):
            obj = obj[part]

        if isinstance(required, (int, IntEnum)):
            if obj < required:
                return False
        else:
            if obj != required:
                return False

    return True


# TODO: add composition invariants from invariants/{composition}.py
INVARIANTS = [
    Invariant(
        name="processed_from_queue",
        requires={"queue.delivery": Delivery.AT_LEAST_ONCE},
        quint="processed.forall(id => history.exists(m => m.id == id))",
    ),
    Invariant(
        name="all_kv_from_queue",
        requires={"kv.idempotent_writes": True},
        quint="""
        mapToSet(kv).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            processed.contains(m.id)
          )
        )
        """,
    ),
    Invariant(
        name="exactly_once",
        requires={
            "queue.delivery": Delivery.AT_LEAST_ONCE,
            "kv.consistency": Consistency.STRONG.value,
            "kv.conditional_writes": True,
        },
        quint="""
        history.forall(m =>
          processed.contains(m.id)
            iff kv.getOrElse(m.key, -1) == m.value
        )
        """,
    ),
    Invariant(
        name="at_most_once",
        requires={
            "queue.delivery": Delivery.AT_MOST_ONCE,
        },
        quint="""
      processed.forall(id =>
            processed.forall(other_id =>
                id == other_id or
                history.filter(m => m.id == id).size() == 1
            )
        )
      """,
    ),
    Invariant(
        name="crash_safety",
        requires={
            "queue.type": "Redis",
        },
        quint="""
      // Crashes should not occur unless specified in the system model
      history.size() == queue.size() + inflight.size() + processed.size()
      """,
    ),
]
