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
        processed' = processed
    }
    action compositeDeliver(m: Message): bool = all {
        deliver(m),
        kv' = kv,
        processed' = processed
    }


    // Unified Step
    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()

        val input: Message = {id: id, key: k, value: v}

        any {
            compositeEnqueue(input),
            compositeDeliver(getHead(queue)),
            process(getHead(inflight))
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
