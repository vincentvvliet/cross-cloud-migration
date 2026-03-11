module BasePubSub {
    import BaseMessaging.* from "baseMessaging"
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    var topics: int -> Set[Message]
    var subscriptions: int -> Set[int]   // subscriber → topics

    action initPubSub = all {
        initMessaging,
        topics' = Map(),
        subscriptions' = Map(),
    }

    pure def recipients(m: Message): Set[int] =
        subscriptions
            .keys()
            .filter(s =>
                subscriptions.get(s).contains(m.key)
            )

    action publishTopic(topic: int, m: Message): bool = all {
        publish(m),

        topics' = topics.put(topic, topics.get(topic).union(Set(m)))
    }

    action deliverSub(sub: int, topic: int, m: Message): bool = all {
        require(m.in(topics.get(topic))),
        require(subscriptions.get(sub).contains(topic)),

        deliver(sub, m)
    }

    val pubsub_invariants = messaging_invariants
}