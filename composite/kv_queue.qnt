module KV_Queue_Base {
    import commonSpells.* from "../helper/commonSpells"
    import basicSpells.* from "../helper/basicSpells"

    pure val VALUES: Set[int] = 0.to(100)

    type Message = {
        id: int,
        key: int,
        value: int
    }
    
    // State
    var queue: Set[Message]       // messages available for delivery
    var inflight: Set[Message]     // delivered but not yet acked
    var kv: int -> int          // key-value store
    var processed: Set[int]         // message IDs already applied
    var delivered: Set[Message]
    
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
        // TODO:
        queue' = queue,          
        inflight' = inflight,
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
    }

    action kvUnchanged = all {
        // TODO:
        queue' = queue,          
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
    }

    // Actions
    action init = all {
        // At the initial state, all balances are zero
        queue' = Set(),
        delivered' = Set(),
        inflight' = Set(),
        kv' = Set().setToMap(), // Empty map
        processed' = Set(),
    }

    // Queue Actions
    action enqueue(m: Message): bool = all {
        queue' = queue.union(Set(m)),
        inflight' = inflight,
        kv' = kv,
        processed' = processed,
        delivered' = delivered,
    }

    action deliver(m: Message): bool = all {
        require(m.in(queue)),
        
        queue' = queue, //setRemove(queue, m),          // TODO: check redelivery
        inflight' = inflight.union(Set(m)),
        kv' = kv,
        processed' = processed,
        delivered' = delivered
    }

    // Integration actions
    action process(m: Message): bool = all{
        require(m.in(inflight)),

        if (not (processed.contains(m.id))) all {
            inflight' = setRemove(inflight, m),
            kv' = kv.put(m.key, m.value),
            processed' = processed.union(Set(m.id)),
            queue' = queue,
            delivered' = delivered
        } else all {
            // Already processed message
            allUnchanged
        }
    }

    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()

        val input: Message = {id: id, key: k , value: v}

        any {
            // Process: enqueue -> deliver -> process
            enqueue(input),
            deliver(getHead(queue)), // TODO: random selection?
            process(getHead(inflight)), // TODO: random selection?
        }
    }

    // Invariants
    val no_negative_size = size(kv.keys()) >= 0
    val no_loss = inflight.subseteq(queue)
    val all_kv_from_queue = 

    val base_invariants = all {
        no_negative_size,
        no_loss, // TODO: check if necessary. Only works if queue allows redelivery (no deletion upon deliver)
        
        // TODO: more invariants
    }
}