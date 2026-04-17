
module KVQueue {
    import BaseQueue.* from "../queue/baseQueue"
    import BaseKV.* from "../kv/baseKV"
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"
    
    // Composition State
    var processed: List[(Recipient, Message)] // list of (recipient, message) pairs that have been processed

    // Init
    action initComposition = all {
        processed' = List()
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
    // action process(recipient: int, m: Message, r: Replica): bool = all {
    //     // require(inflight.contains((recipient, m))),
    //     require(r.in(kv.keys())),

    //     if (not(processed.contains((recipient, m)))) all {

    //         // apply effect exactly once per (recipient, message)
    //         kv' = kv.put(r, kv.get(r).put(m.key, m.value)),

    //         processed' = processed.union(Set((recipient, m))),

    //         inflight' = setRemove(inflight, (recipient, m)),

    //         queue' = queue,
    //         delivered' = delivered,
    //         history' = history,
    //         visibleReplicas' = visibleReplicas,

    //         lastWrite' = lastWrite.put(
    //             m.client, 
    //             lastWrite.get(m.client).put(m.key, m.value)
    //         )

    //     } else all {
    //         // duplicate processing attempt
    //         // TODO: handle duplicate processing. Should be allowed if delivery is at least once, disallowed if exactly once (simulate drop)
    //         allUnchanged
    //     }
    // }

    action process(recipient: int, m: Message, r: Replica, mode: int): bool = all {
        require(r.in(kv.keys())),
        require(recipient.in(m.recipients)), // Also handles failure in case of empty inflight

        if (DELIVERY_MODE == AT_MOST_ONCE and mode == 0) all {
            // skip processing entirely
            inflight' = setRemove(inflight, (recipient, m)),
            queue' = queue,          
            kv' = kv,
            processed' = processed,
            delivered' = delivered,
            history' = history,
            lastWrite' = lastWrite,
            visibleReplicas' = visibleReplicas,
        } else all  {
            queue' = queue,
            delivered' = delivered,
            history' = history,
            visibleReplicas' = visibleReplicas,

            action process_message = all {
                kv' = kv.put(r, kv.get(r).put(m.key, m.value)),
                processed' = processed.append((recipient, m)),
                inflight' = setRemove(inflight, (recipient, m)),
                lastWrite' = lastWrite.put(
                    m.client,
                    lastWrite.get(m.client).put(m.key, m.value)
                )
            }

            // EXACTLY ONCE → enforce deduplication
            if (DELIVERY_MODE == EXACTLY_ONCE) {
                if (not(convertToSet(processed).contains((recipient, m)))) all {
                    process_message
                } else all {
                    // duplicate → drop
                    kv' = kv,
                    processed' = processed,
                    inflight' = setRemove(inflight, (recipient, m)),
                    lastWrite' = lastWrite,
                }
            } else all {
                // AT LEAST ONCE → allow duplicates
                process_message
            }
        }
    }

    // --------------------
    // Hybrid Invariants
    // --------------------

    // KV writes are caused by processed messages
    val kv_size_bounded = kv_view.keys().size() <= size(convertToSet(processed))

    // No processing after acknowledgment
    val no_processing_after_ack =
        inflight.forall(p =>
            not(convertToSet(processed).contains((p)))
        )

    // Eventual consistency-style causality
    val kv_values_eventually_from_processed =
        kv_view.keys().forall(k =>
            convertToSet(processed).exists(p =>
                history.exists(m =>
                    m.id == p._2.id and m.key == k
                )
            )
        )
    
    // FIFO ordering
    // TODO: rewrite such that for all processed messages, 
    // val fifo_ordering =
    //     history.forall(m1 =>
    //         history.forall(m2 =>
    //             (m1.id < m2.id) implies
    //                 processed.forall(p2 =>
    //                     (p2._2 == m2.id) implies
    //                         processed.exists(p1 =>
    //                             p1._1 == p2._1 and p1._2 == m1.id
    //                         )
    //                 )
    //         )
    //     )

    val composition_invariants = all {
        kv_size_bounded,
        no_processing_after_ack,
    }

    val composition_specific_invariants = all {
        kv_values_eventually_from_processed, //TODO: fix
    }

}