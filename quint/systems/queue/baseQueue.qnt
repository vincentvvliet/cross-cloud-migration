module BaseQueue {
    // import BaseMessaging. * from "baseMessaging"
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
        require(history.forall(p => p.id != m.id)),

        queue' = queue.union(Set(m)),
        history' = history.union(Set(m)),
        inflight' = inflight,
        delivered' = delivered,
    }

    // alias used by pub/sub systems
    action publish(m: Message): bool =
        enqueue(m)

    // ---- DELIVERY ----

    // generic delivery
    action deliver(recipient: int, m: Message): bool = all {
        require(m.in(queue)),
        require(recipient.in(m.recipients)),

        queue' = setRemove(queue, m),
        inflight' = inflight.union(Set((recipient, m))),
        history' = history,
        delivered' = delivered,
    }

    // ---- ACK / DELETE ----

    // action ack(recipient: int, m: Message): bool = all {
    //     require(inflight.contains((recipient, m))),

    //     inflight' = setRemove(inflight, (recipient, m)),
    //     delivered' = delivered.union(Set((recipient, m))),
    //     queue' = queue,
    //     history' = history,
    // }

    action delete(m: Message): bool = all {
        require(m.in(queue)),

        queue' = setRemove(queue, m),
        inflight' = inflight,
        delivered' = delivered.union(Set((m.recipients, m))),
        history' = setRemove(history, m), // deletion removes from history to uphold exaclty-once invariant
    }

    // ---- INVARIANTS ----

    val inflight_origin =
        inflight.forall(p => history.contains(p._2))

    val valid_recipients =
        inflight.forall(p => p._1.in(p._2.recipients))

    val queue_invariants = all {
        inflight_origin,
        valid_recipients,
    }
}