module System {
    import Types.* from "../systems/common/types"
    import basicSpells.* from "../systems/common/basicSpells"
    import GeneratedInvariants.* from "./generated_invariants"

    import BaseKV.* from "../systems/kv/baseKV"
    import RabbitMQ.* from "../systems/queue/rabbitMQ"
    import KVQueue.* from "../systems/compositions/kvQueue"

    var nextMessageId: int // Global message ID generator

    // Unified Init
    action init = all {
        initKV,
        initQueue,
        initComposition,
        nextMessageId' = 1,
    }

    // All Unchanged
    action AllUnchanged = all {
        nextMessageId' = nextMessageId, kv' = kv, lastWrite' = lastWrite, visibleReplicas' = visibleReplicas, queue' = queue, inflight' = inflight, history' = history, delivered' = delivered, processed' = processed 
    }
        
    action compositeSync(r1: Replica, r2: Replica): bool = all {
        sync(r1, r2),
        nextMessageId' = nextMessageId,
        queue' = queue,
        inflight' = inflight,
        history' = history,
        delivered' = delivered,
        processed' = processed
    }
    action compositeEnqueue(m: Message): bool = all {
        enqueue(m),
        nextMessageId' = nextMessageId + 1,
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }
    action compositeDeliver(m: Message, deliveryChoice: int): bool = all {
        deliver(m, deliveryChoice),
        nextMessageId' = nextMessageId,
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }
    action compositeDelete(m: Message): bool = all {
        delete(m),
        nextMessageId' = nextMessageId,
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }


    // Unified Step
    action step = {
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()
        nondet client: int = CLIENTS.oneOf()
        nondet replica: int = REPLICAS.oneOf()
        nondet recipients: Set[int] = CONSUMERS.oneOf()
        nondet dst: int = REPLICAS.filter(r => r != replica).oneOf()

        val input: Message = {id: nextMessageId, key: k, value: v, client: client, recipients: recipients}
                
        // Random message from the queue for non-ordered delivery
        nondet deliveryChoice: Message = oneOf(if (queue.empty()) {
            Set({id: nextMessageId, key: 0, value: 0, client: 0, recipients: Set()})
        } else {
            queue
        })

        // Determine ordering
        // TODO: global ordering?
        val deliveryTarget = if (ORDERING_MODE == FIFO) {
            // FIFO
            queue
        } else {
            // No ordering, deliver random message in the queue
            Set(deliveryChoice)
        }

        nondet processChoice: (Recipient, Message) = oneOf(if (inflight.empty()) {
            Set((-1, {id: -1, key: -1, value: -1, client: 1, recipients: Set()}))
        } else {
            inflight
        })

        // Determine ordering of processing
        val processTarget = if (ORDERING_MODE == FIFO) {
            // FIFO
            inflight
        } else {
            // No ordering, process random message in the inflight
            Set(processChoice)
        }

        // Nondeterministic Delivery Mode: 0 = drop, 1 = normal, 2 = duplicate
        nondet deliveryMode: int = oneOf(Set(0, 1, 2))

        any {
            if (queue.empty()) compositeEnqueue(input) // Force enqueue if queue is empty to ensure progress and avoid deadlock
            else any {
                compositeSync(replica, dst),
                compositeEnqueue(input),
                match getHead(deliveryTarget) {
                    | Some(m) => compositeDeliver(m, deliveryMode)
                    | None => AllUnchanged
                },
                match getHead(queue) {
                    | Some(m) => compositeDelete(m)
                    | None => AllUnchanged
                },
                match getHead(processTarget) {
                    | Some(m) => all { process(m._1, m._2, replica, deliveryMode), nextMessageId' = nextMessageId }
                    | None => AllUnchanged
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
