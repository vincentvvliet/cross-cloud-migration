module KVQueue {
    import BaseQueue.* from "../queue/baseQueue"
    import BaseKV.* from "../kv/baseKV"
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"
    
    // Composition State
    var processed: Set[(int, Message)] // set of (recipient, message) pairs that have been processed

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
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
    }

    // Consumer Logic
    action process(recipient: int, m: Message, r: Replica): bool = all {
        require(inflight.contains((recipient, m))),
        require(r.in(kv.keys())),

        if (not(processed.contains((recipient, m)))) all {

            // apply effect exactly once per (recipient, message)
            kv' = kv.put(r, kv.get(r).put(m.key, m.value)),

            processed' = processed.union(Set((recipient, m))),

            inflight' = setRemove(inflight, (recipient, m)),

            queue' = queue,
            delivered' = delivered,
            history' = history,
            visibleReplicas' = visibleReplicas,

            lastWrite' = lastWrite.put(
                m.client, 
                lastWrite.get(m.client).put(m.key, m.value)
            )

        } else all {
            // duplicate processing attempt
            allUnchanged
        }
    }

    // --------------------
    // Hybrid Invariants
    // --------------------

    // KV writes are caused by processed messages
    val kv_size_bounded = kv_view.keys().size() <= size(processed)

    // At-least-once safety: deduplication works
    val no_double_processing =
        processed.forall(p =>
            size(history.filter(m => m.id == p._2.id)) == 1
        )

    // No processing after acknowledgment
    val no_processing_after_ack =
        inflight.forall(p =>
            not(processed.contains((p)))
        )

    // Eventual consistency-style causality
    val kv_values_eventually_from_processed =
        kv_view.keys().forall(k =>
            processed.exists(p =>
                history.exists(m =>
                    m.id == p._2.id and m.key == k
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