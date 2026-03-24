module System {
    import Types.* from "../systems/common/types"
    import basicSpells.* from "../systems/common/basicSpells"
    import GeneratedInvariants.* from "./generated_invariants"

    import BaseQueue.* from "../systems/queue/baseQueue"
    import BaseKV.* from "../systems/kv/baseKV"
    import KVQueue.* from "../systems/compositions/kvQueue"

    // Unified Init
    action init = all {
        initQueue,
        initKV,
        initComposition
    }

    action compositeEnqueue(m: Message): bool = all {
        enqueue(m),
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        processed' = processed
    }
    action compositeDeliver(m: Message): bool = all {
        deliver(m),
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
        

        val input: Message = {id: id, key: k, value: v, client: client, recipients: recipients}

        any {
            compositeEnqueue(input),
            match getHead(queue) {
                | Some(m) => compositeDeliver(m)
                | None => allUnchanged
            },
            match getHead(inflight) {
                | Some(m) => process(m._1, m._2, replica)
                | None => allUnchanged
            }
        }
    }


    // Base Invariants
    val base_invariants = all {
        queue_invariants,
        kv_invariants,
        composition_invariants,    
    }   


    // Full System Invariants
    val SystemCorrect =
        base_invariants and
        composition_specific_invariants and
        generated_invariants
}
