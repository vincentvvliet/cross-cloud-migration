module BaseQueue {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    // ---- STATE ----
    var queue: Set[Message]
    var inflight: Set[(Recipient, Message)]
    var history: Set[Message]
    var delivered: Set[(Recipient, Message)]

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
    // action deliver(m: Message): bool = all {
    //     require(m.in(queue)),

    //     queue' = setRemove(queue, m),
    //     inflight' = inflight.union(m.recipients.map(r => (r, m))),
    //     history' = history,
    //     delivered' = delivered,
    // }

    action deliver(m: Message, mode: int): bool = all {
        require(m.in(queue)),
        // If exactly once is required, message must not have been delivered before, else skip delivery (simulate drop)
        require((DELIVERY_MODE == EXACTLY_ONCE) implies (not (inflight.exists(p => p._2.id == m.id)))),

        // AT MOST ONCE: allow drop (no delivery)
        if (DELIVERY_MODE == AT_MOST_ONCE and mode == 0) all {
            queue' = setRemove(queue, m),
            inflight' = inflight,
            delivered' = delivered,
            history' = history
        } else all {
            // --- NORMAL DELIVERY ---
            val newInflight = inflight.union(m.recipients.map(r => (r, m)))

            // AT LEAST ONCE: allow duplicates
            if (DELIVERY_MODE == AT_LEAST_ONCE and mode == 2) all {
                // duplicate delivery, keep in queue for potential redelivery
                queue' = queue, 
                inflight' = newInflight.union(m.recipients.map(r => (r, m)))
            } else all {
                queue' = setRemove(queue, m),
                inflight' = newInflight,
            },
            
            history' = history,
            delivered' = delivered
        }
    }

    // ---- DELETE ----
    // action delete(m: Message): bool = all {
    //     require(m.in(queue)),

    //     queue' = setRemove(queue, m),
    //     inflight' = inflight,
    //     delivered' = delivered.union(m.recipients.map(r => (r, m))), // TODO: check if this is correct for pub/sub. We want to mark as delivered to all recipients
    //     history' = setRemove(history, m), // deletion removes from history to uphold exaclty-once invariant
    // }

    action delete(m: Message): bool = all {
        require(m.in(queue)),

        if (DELIVERY_MODE == EXACTLY_ONCE) all {
            delivered' = delivered.union(m.recipients.map(r => (r, m))),
            history' = setRemove(history, m),
            queue' = setRemove(queue, m),
            inflight' = inflight,
        } else all {
            // weaker guarantees → no strict tracking
            delivered' = delivered,
            history' = history,
            queue' = setRemove(queue, m),
            inflight' = inflight,
        }
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