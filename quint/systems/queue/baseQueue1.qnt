module BaseQueue {
    import BaseMessaging.* from "baseMessaging"
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    pure val QUEUE_MAX_SIZE: int = 20

    var queue: Set[Message]

    action initQueue = all {
        initMessaging,
        queue' = Set()
    }

    action enqueue(m: Message): bool = all {
        require(not(history.contains(m))),
        require(queue.size() < QUEUE_MAX_SIZE),

        queue' = queue.union(Set(m)),
        history' = history.union(Set(m)),
        inflight' = inflight,
        delivered' = delivered
    }

    action deliverQueue(m: Message): bool = all {
        require(m.in(queue)),

        queue' = setRemove(queue, m),
        deliver(1, m)  // single consumer
    }

    val queue_invariants = all {
        messaging_invariants
    }
}