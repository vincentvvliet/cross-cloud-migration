from typing import Callable
from capabilities import SystemCaps, Delivery, Consistency
from dataclasses import dataclass
from typing import Any
from enum import IntEnum
from load_systems import import_systems

_, QUEUE_SYSTEMS, KV_SYSTEMS = import_systems()


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
        quint="convertToSet(processed).forall(p => history.exists(m => m.id == p._2.id))",
    ),
    Invariant(
        name="no_double_processing",
        requires={"queue.delivery": Delivery.AT_LEAST_ONCE},
        quint="""
        convertToSet(processed).forall(p =>
            size(history.filter(m => m.id == p._2.id)) == 1
        )""",
    ),
    Invariant(
        name="all_kv_from_queue",
        requires={"kv.idempotent_writes": True},
        quint="""
        mapToSet(kv_view).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            convertToSet(processed).map(p => p._2.id).contains(m.id)
          )
        )
        """,
    ),
    Invariant(
        name="exactly_once",
        requires={
            "queue.delivery": Delivery.AT_LEAST_ONCE,
            "kv.consistency": Consistency.STRONG,
            "kv.conditional_writes": True,
        },
        quint="""
        history.forall(m =>
          convertToSet(processed).map(p => p._2.id).contains(m.id)
            iff kv_view.getOrElse(m.key, -1) == m.value
        )
        """,
    ),
    Invariant(
        name="at_most_once",
        requires={
            "queue.delivery": Delivery.AT_MOST_ONCE,
        },
        quint="""
      convertToSet(processed).forall(p =>
            convertToSet(processed).forall(other_p =>
                p._2.id == other_p._2.id or
                history.filter(m => m.id == p._2.id).size() == 1
            )
        )
      """,
    ),
    Invariant(
        name="crash_safety",
        requires={
            "queue.type": (" or ").join([s for s in QUEUE_SYSTEMS if s != "Redis"]),
        },
        quint="""
      // Crashes should not occur unless specified in the system model
      history.size() == queue.size() + inflight.size() + convertToSet(processed).size()
      """,
    ),
]
