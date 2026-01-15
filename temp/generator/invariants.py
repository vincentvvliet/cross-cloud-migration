from typing import Callable
from capabilities import SystemCaps, Delivery, Consistency

class Invariant:
    def __init__(self, name: str,
                 condition: Callable[[SystemCaps], bool],
                 quint: str):
        self.name = name
        self.condition = condition
        self.quint = quint


INVARIANTS = [

    Invariant(
        "processed_from_queue",
        lambda c: c.queue.delivery == Delivery.AT_LEAST_ONCE,
        "processed.forall(id => history.exists(m => m.id == id))"
    ),

    Invariant(
        "all_kv_from_queue",
        lambda c: c.kv.idempotent_writes,
        """
        mapToSet(kv).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            processed.contains(m.id)
          )
        )
        """
    ),

    Invariant(
        "exactly_once",
        lambda c:
          c.queue.delivery == Delivery.AT_LEAST_ONCE and
          c.kv.conditional_writes and
          c.kv.consistency == Consistency.STRONG,
        """
        history.forall(m =>
          processed.contains(m.id)
            iff kv.getOrElse(m.key, -1) == m.value
        )
        """
    )
]
