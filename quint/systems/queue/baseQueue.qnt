module BaseQueue {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    // ---- STATE ----
    var queue: Set[Message]
    var inflight: Set[(int, Message)]
    var history: Set[Message]
    var delivered: Set[(int, Message)]

    // ---- INIT ----
    action initQueue = all {
        queue' = Set(),
        inflight' = Set(),
        history' = Set(),
        delivered' = Set(),
    }

    // ---- PRODUCER ACTIONS ----

    action enqueue(m: Message): bool = all {
        require(history.forall(p => p.id != m.id and p.key != m.key)),
        require(queue.size() < QUEUE_MAX_SIZE),

        queue' = queue.union(Set(m)),
        history' = history.union(Set(m)),
        inflight' = inflight,
        delivered' = delivered,
    }

    // alias used by pub/sub systems
    action publish(m: Message): bool = enqueue(m)

    // ---- DELIVERY ----

    // generic delivery
    action deliver(m: Message): bool = all {
        require(m.in(queue)),

        queue' = setRemove(queue, m),
        inflight' = inflight.union(m.recipients.map(r => (r, m))),
        history' = history,
        delivered' = delivered,
    }

    // ---- ACK / DELETE ----

    // action ack(m: Message): bool = all {
    //     require(m.recipients.forall(r => inflight.contains((r, m)))),

    //     inflight' = setRemove(inflight, (m.recipients, m)),
    //     delivered' = delivered.union(Set((m.recipients, m))),
    //     queue' = queue,
    //     history' = history,
    // }

    action delete(m: Message): bool = all {
        require(m.in(queue)),

        queue' = setRemove(queue, m),
        inflight' = inflight,
        delivered' = delivered.union(m.recipients.map(r => (r, m))), // TODO: check if this is correct for pub/sub. We want to mark as delivered to all recipients
        history' = setRemove(history, m), // deletion removes from history to uphold exaclty-once invariant
    }

    // ---- INVARIANTS ----
    val queue_max_size = size(queue) <= QUEUE_MAX_SIZE
    val queue_no_negative_size = size(queue) >= 0

    val inflight_originates_from_queue =
        inflight.map(r => r._2).subseteq(history)

    val unique_keys_per_message =
        history.forall(m1 =>
            history.forall(m2 =>
                m1.id != m2.id implies m1.key != m2.key
            )
        )

    val inflight_origin =
        inflight.forall(p => history.contains(p._2))

    val valid_recipients =
        inflight.forall(p => p._1.in(p._2.recipients))

    val queue_invariants = all {
        queue_max_size,
        queue_no_negative_size,
        inflight_origin,
        valid_recipients,
        inflight_originates_from_queue,
        unique_keys_per_message,
    }
}