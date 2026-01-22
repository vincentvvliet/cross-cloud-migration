module KVQueue {
    import BaseQueue.* from "../queue/baseQueue"
    import BaseKV.* from "../kv/baseKV"
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"
    
    // Composition State
    var processed: Set[int]

    // Init
    action initComposition = all {
        processed' = Set()
    }

    action allUnchanged = all {
        queue' = queue,          
        inflight' = inflight,
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
        history' = history,
    }

    // Consumer Logic
    action process(m: Message): bool = all {
        require(m.in(inflight)),

        if (not(processed.contains(m.id))) all {
            // apply effect exactly once
            kv' = kv.put(m.key, m.value),
            processed' = processed.union(Set(m.id)),
            inflight' = setRemove(inflight, m),
            queue' = queue,
            delivered' = delivered,
            history' = history,
        } else all {
            // duplicate delivery
            allUnchanged
        }
    }

    // --------------------
    // Hybrid Invariants
    // --------------------

    // KV writes are caused by processed messages
    val kv_size_bounded =
        size(kv.keys()) <= size(processed)

    // At-least-once safety: deduplication works
    val no_double_processing =
        processed.forall(id =>
            size(history.filter(m => m.id == id)) == 1
        )

    // No processing after acknowledgment
    val no_processing_after_ack =
        inflight.forall(m =>
            not(processed.contains(m.id))
        )

    // Eventual consistency-style causality
    val kv_values_eventually_from_processed =
        kv.keys().forall(k =>
            processed.exists(id =>
                history.exists(m =>
                    m.id == id and m.key == k
                )
            )
        )

    val composition_invariants = all {
        kv_size_bounded,
        no_processing_after_ack,
    }

    val composition_specific_invariants = all {
        no_double_processing,
        kv_values_eventually_from_processed,
    }
}
