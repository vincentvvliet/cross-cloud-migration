module Base {
    import commonSpells.* from "../../helper/commonSpells"
    import basicSpells.* from "../../helper/basicSpells"

    pure val VALUES: Set[int] = 0.to(100)
    pure val QUEUE_MAX_SIZE: int = 20
    pure val KV_MAX_SIZE: int = 20

    type Message = {
        id: int,
        key: int,
        value: int
    }
    
    // State
    var history: Set[Message]    // Log queue messages
    var queue: Set[Message]      // messages available for delivery
    var inflight: Set[Message]   // delivered but not yet acked
    var kv: int -> int           // key-value store
    var processed: Set[int]      // message IDs already applied
    var delivered: Set[Message]  // TODO: 
    
    // Input
    var input: Message

    // Helpers
    def convertToList(s: Set[a]): List[a] = 
        (s.fold([], (acc, x) => acc.append(x)))

    def getHead(s: Set[Message]): Message = {
        if (s.size() >= 1) {
            convertToList(s).head()
        }
        else {
            {id: -1, key: -1 , value: -1}
        }
    }

    action queueUnchanged = all {
        queue' = queue,          
        inflight' = inflight,
        processed' = processed,
        delivered' = delivered,
        history' = history,
    }

    action kvUnchanged = all {  
        inflight' = inflight,
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
    }

    action allUnchanged = all {
        queue' = queue,          
        inflight' = inflight,
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
        history' = history,
    }

    // Actions
    action init = all {
        // At the initial state, all balances are zero
        queue' = Set(),
        delivered' = Set(),
        inflight' = Set(),
        kv' = Set().setToMap(), // Empty map
        processed' = Set(),
        history' = Set(),
    }

    // Queue Actions
    action enqueue(m: Message): bool = all {
        // Require unique key and id
        require(history.forall(p => m.id != p.id and m.key != p.key)), 
        require(queue.size() < QUEUE_MAX_SIZE),
        require(kv.keys().size() < KV_MAX_SIZE),

        queue' = queue.union(Set(m)),
        history' = history.union(Set(m)),
        kvUnchanged,
    }

    action deliver(m: Message): bool = all {
        require(m.in(queue)),
        
        queue' = setRemove(queue, m),          // TODO: check redelivery
        inflight' = inflight.union(Set(m)),
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
        history' = history,
    }

    // Integration actions
    action process(m: Message): bool = all{
        require(m.in(inflight)),

        if (not (processed.contains(m.id))) all {
            inflight' = setRemove(inflight, m),
            kv' = kv.put(m.key, m.value),
            processed' = processed.union(Set(m.id)),
            queue' = queue,
            delivered' = delivered,
            history' = history,
        } else all {
            // Already processed message
            allUnchanged
        }
    }

    // TODO: 
    action ack(m: Message): bool = all {
        require(inflight.contains(m)),

        inflight' = setRemove(inflight, m),
        queue' = queue,
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
        history' = history,
    }


    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()

        val input: Message = {id: id, key: k , value: v}

        any {
            // Process: enqueue -> deliver -> process
            enqueue(input),
            deliver(getHead(queue)),    // TODO: random selection?
            process(getHead(inflight)), // TODO: random selection?
            // ack(getHead(inflight)),     // TODO: functionality?
        }
    }

    // Invariants

    // KV invariants
    val kv_no_negative_size = size(kv.keys()) >= 0
    val kv_max_size = size(kv.keys()) <= KV_MAX_SIZE

    val keys_within_domain = kv.keys().forall(k => VALUES.contains(k))
    val values_within_domain = kv.keys().forall(k => VALUES.contains(kv.getOrElse(k, -1)))
    val map_is_functional = kv.keys().forall(k => size(mapToSet(kv).filter(kk => kk._1 == k)) <= 1)
    // val no_lost_updates = kv.keys().forall(k => history.get(k).contains(kv.get(k)))

    val kv_invariants = all {
        kv_max_size,
        kv_no_negative_size,
        keys_within_domain, 
        values_within_domain,
        map_is_functional,
    }

    // Queue invariants
    val queue_max_size = size(queue) <= QUEUE_MAX_SIZE
    val queue_no_negative_size = size(queue) >= 0

    val queue_invariants = all {
        queue_max_size,
        queue_no_negative_size,
    }
    
    // Hybrid invariants
    val inflight_originates_from_queue = inflight.subseteq(history) // Safety: currently loss allowed, duplication allowed

    val unique_keys_per_message =
        history.forall(m1 =>
            history.forall(m2 =>
                m1.id != m2.id implies m1.key != m2.key
            )
        )

    val kv_size_bounded = size(kv.keys()) <= size(processed) 


    // At-least-once Queue: deduplication safety
    val no_double_processing =
        processed.forall(id =>
            size(history.filter(m => m.id == id)) == 1
        )

    val no_processing_after_ack =
        inflight.forall(m => not(processed.contains(m.id)))

    // Eventual consistency
    val kv_values_eventually_from_processed =
        kv.keys().forall(k =>
            processed.exists(id =>
                history.exists(m => m.id == id and m.key == k)
            )
        )

    val hybrid_invariants = all {
        inflight_originates_from_queue,
        kv_size_bounded,
    }


    // Callable invariants
    val base_invariants = all {
        kv_invariants, 
        queue_invariants,
        hybrid_invariants,
        unique_keys_per_message,
        no_processing_after_ack,
    }

    val specific_invariants = all {
        no_double_processing,                   // Should fail if system allows retries
        kv_size_bounded,                        // Fails if external writes exist
        kv_values_eventually_from_processed,    // Eventual consistency: weaker than exactly once processing
    }
}