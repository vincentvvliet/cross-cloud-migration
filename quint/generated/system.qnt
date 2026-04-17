module System {
    import Types.* from "../systems/common/types"
    import basicSpells.* from "../systems/common/basicSpells"
    import GeneratedInvariants.* from "./generated_invariants"

    import BaseKV.* from "../systems/kv/baseKV"
    import RabbitMQ.* from "../systems/queue/rabbitMQ"
    import KVQueue.* from "../systems/compositions/kvQueue"

    // Unified Init
    action init = all {
        initKV,
        initQueue,
        initComposition
    }

    action compositeSync(r1: Replica, r2: Replica): bool = all {
        sync(r1, r2),
        queue' = queue,
        inflight' = inflight,
        history' = history,
        delivered' = delivered,
        processed' = processed
    }
    action compositeEnqueue(m: Message): bool = all {
        enqueue(m),
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }
    action compositeDeliver(m: Message, deliveryChoice: int): bool = all {
        deliver(m, deliveryChoice),
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }
    action compositeDelete(m: Message): bool = all {
        delete(m),
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }


    // Unified Step
    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()
        nondet client: int = CLIENTS.oneOf()
        nondet replica: int = REPLICAS.oneOf()
        nondet recipients: Set[int] = CONSUMERS.oneOf()
        nondet dst: int = REPLICAS.filter(r => r != replica).oneOf()
                
        // Random message from the queue for non-ordered delivery
        nondet choice: Message = oneOf(if (queue.empty()) {
            Set({id: 0, key: 0, value: 0, client: 0, recipients: Set()})
        } else {
            queue
        })

        // Nondeterministic Delivery Choice: 0 = drop, 1 = normal, 2 = duplicate
        nondet deliveryChoice: int = oneOf(Set(0, 1, 2))

        val input: Message = {id: id, key: k, value: v, client: client, recipients: recipients}

        // Determine ordering
        // TODO: global ordering?
        val deliveryTarget = if (ORDERING_MODE == FIFO) {
            // FIFO
            queue
        } else {
            // No ordering, deliver any message in the queue
            Set(choice)
        }

        any {
            if (queue.empty()) compositeEnqueue(input) // Force enqueue if queue is empty to ensure progress and avoid deadlock
            else any {
                compositeSync(replica, dst),
            compositeEnqueue(input),
            match getHead(deliveryTarget) {
                | Some(m) => compositeDeliver(m, deliveryChoice)
                | None => allUnchanged
            },
            match getHead(queue) {
                | Some(m) => compositeDelete(m)
                | None => allUnchanged
            },
            match getHead(inflight) {
                | Some(m) => process(m._1, m._2, replica)
                | None => allUnchanged
            }
            }
        }
    }


    // Base Invariants
    val base_invariants = all {
        kv_invariants,
        queue_invariants,
        composition_invariants,    
    }   


    // Full System Invariants
    val SystemCorrect =
        base_invariants and
        composition_specific_invariants and
        generated_invariants
}
