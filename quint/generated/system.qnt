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
    action compositeSync(m: Message, r1: Replica, r2: Replica): bool = all {
        sync(r1, r2),
        queue' = queue,
        inflight' = inflight,
        history' = history,
        delivered' = delivered,
        processed' = processed
    }


    // Unified Step
    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()
        nondet client: int = CLIENTS.oneOf()
        nondet replica: int = REPLICAS.oneOf()
        nondet dst: int = REPLICAS.filter(r => r != replica).oneOf()

        val input: Message = {id: id, key: k, value: v, client: client}

        any {
            compositeEnqueue(input),
            compositeDeliver(getHead(queue)),
            compositeSync(input, replica, dst),
            process(getHead(inflight), replica)
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
