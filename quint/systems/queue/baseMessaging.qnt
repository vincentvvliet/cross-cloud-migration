module BaseMessaging {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    var history: Set[Message]

    // delivery tracking
    var inflight: Set[(int, Message)]
    var delivered: Set[(int, Message)]

    action initMessaging = all {
        history' = Set(),
        inflight' = Set(),
        delivered' = Set()
    }

    action deliver(recipient: int, m: Message): bool = all {
        require(history.contains(m)),
        require(not(inflight.contains((recipient, m)))),

        inflight' = inflight.union(Set((recipient, m))),
        history' = history,
        delivered' = delivered
    }

    action ack(recipient: int, m: Message): bool = all {
        require(inflight.contains((recipient, m))),

        inflight' = setRemove(inflight, (recipient, m)),
        delivered' = delivered.union(Set((recipient, m))),
        history' = history
    }

    val delivery_origin =
        inflight.forall(p => history.contains(p._2))

    val messaging_invariants = all {
        delivery_origin
    }
}