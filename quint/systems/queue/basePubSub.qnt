module BasePubSub {
    import BaseMessaging.* from "baseMessaging"
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    var topics: int -> Set[Message]
    var subscriptions: int -> Set[int]

    action initPubSub = all {
        initMessaging,
        topics' = Map(),
        subscriptions' = Map()
    }

    action publish(topic: int, m: Message): bool = all {
        require(not(history.contains(m))),

        topics' = topics.put(topic, topics.get(topic).union(Set(m))),
        history' = history.union(Set(m)),
        inflight' = inflight,
        delivered' = delivered
    }

    action deliverPubSub(sub: int, topic: int, m: Message): bool = all {
        require(subscriptions.get(sub).contains(topic)),
        require(m.in(topics.get(topic))),

        deliver(sub, m)
    }

    val pubsub_invariants = all {
        messaging_invariants
    }
}