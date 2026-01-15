module InvariantMapping {
    import KVQueueBase.* from "./kv_queue"

    def required_invariants(queueCap, kvCap) =
        all {
            queueCap == AtLeastOnce implies all {
                processed_from_queue,
                no_double_processing
            },

            kvCap.idempotentWrites implies all_kv_from_queue,

            kvCap.conditionalWrites and queueCap == AtLeastOnce implies exactly_once,

            kvCap.consistency == Eventual implies kv_values_eventually_from_processed,
        }    
    
}