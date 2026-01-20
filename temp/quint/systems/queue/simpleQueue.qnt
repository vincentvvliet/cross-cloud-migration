module SimpleQueue {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    pure val QUEUE_MAX_SIZE: int = 20

    // Queue State
    var history: Set[Message]
    var queue: Set[Message]
    var inflight: Set[Message]
    var delivered: Set[Message]

    // Helpers
    def convertToList(s: Set[a]): List[a] =
        (s.fold([], (acc, x) => acc.append(x)))

    def getHead(s: Set[Message]): Message = {
        if (s.size() >= 1) convertToList(s).head()
        else {id: -1, key: -1, value: -1}
    }

    // Init
    action initQueue = all {
        queue' = Set(),
        inflight' = Set(),
        delivered' = Set(),
        history' = Set(),
    }

    // Queue Actions
    action enqueue(m: Message): bool = all {
        require(history.forall(p => m.id != p.id and m.key != p.key)),
        require(queue.size() < QUEUE_MAX_SIZE),

        queue' = queue.union(Set(m)),
        history' = history.union(Set(m)),
        inflight' = inflight,
        delivered' = delivered,
    }

    action deliver(m: Message): bool = all {
        require(m.in(queue)),

        queue' = setRemove(queue, m),
        inflight' = inflight.union(Set(m)),
        delivered' = delivered,
        history' = history,
    }

    action ack(m: Message): bool = all {
        require(inflight.contains(m)),

        inflight' = setRemove(inflight, m),
        queue' = queue,
        delivered' = delivered,
        history' = history,
    }

    // Queue Invariants
    val queue_max_size = size(queue) <= QUEUE_MAX_SIZE
    val queue_no_negative_size = size(queue) >= 0

    val inflight_originates_from_queue =
        inflight.subseteq(history)

    val unique_keys_per_message =
        history.forall(m1 =>
            history.forall(m2 =>
                m1.id != m2.id implies m1.key != m2.key
            )
        )

    val queue_invariants = all {
        queue_max_size,
        queue_no_negative_size,
        inflight_originates_from_queue,
        unique_keys_per_message,
    }
}
