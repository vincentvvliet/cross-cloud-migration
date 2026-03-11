module BaseMessaging {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    pure val MAX_MESSAGES: int = 20

    // Message storage
    var history: Set[Message]

    // delivery tracking
    var inflight: Set[(int, Message)]      // (recipient, message)
    var delivered: Set[(int, Message)]

    // Init
    action initMessaging = all {
        history' = Set(),
        inflight' = Set(),
        delivered' = Set(),
    }

    // Publish
    action publish(m: Message): bool = all {
        require(history.size() < MAX_MESSAGES),
        require(history.forall(p => p.id != m.id)),

        history' = history.union(Set(m)),
        inflight' = inflight,
        delivered' = delivered,
    }

    // Deliver message to a recipient
    action deliver(r: int, m: Message): bool = all {
        require(history.contains(m)),
        require(r.in(m.recipients)),
        require(not(inflight.contains((r, m)))),

        inflight' = inflight.union(Set((r, m))),
        history' = history,
        delivered' = delivered,
    }

    // Acknowledge processing
    action ack(r: int, m: Message): bool = all {
        require(inflight.contains((r, m))),

        inflight' = setRemove(inflight, (r, m)),
        delivered' = delivered.union(Set((r, m))),
        history' = history,
    }

    // --------------------
    // Messaging invariants
    // --------------------

    val inflight_origin =
        inflight.forall(p =>
            history.contains(p._2)
        )

    val delivered_origin =
        delivered.forall(p =>
            history.contains(p._2)
        )

    val no_duplicate_delivery =
        delivered.forall(p =>
            not(inflight.contains(p))
        )

    val messaging_invariants = all {
        inflight_origin,
        delivered_origin,
        no_duplicate_delivery
    }
}