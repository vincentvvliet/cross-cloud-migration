module DynamoDB {
    import KVStoreBase.* from "./base_kv_store"

    action step = {
        nondet value = VALUES.oneOf()
        nondet key = KEYS.oneOf()
        any {
            put_action(key, value),
            get_action(key),
            delete(key),
        }
    }

    // DynamoDB-specific Invariants

    // Primary key uniqueness
//     forall i1, i2 in Items:
//   if i1.pk == i2.pk and i1.sk == i2.sk then i1 == i2

    // last-writer-wins for single item (latest timestamp)

    // atomicity per item
//     forall k in Keys:
//   StateBefore(k) == StateAfter(k) or StateAfter(k) == AtomicWrite(StateBefore(k), op)

    // total order per partition
//     forall p in Partitions:
//   IsTotallyOrdered(WriteHistory(p))

    // no ordering cross partition
//     forall p1 != p2:
//   not IsOrdered(WriteHistory(p1), WriteHistory(p2))


    // streams is at least once delivery
//     forall op in Writes:
//   if op.committed then Count(StreamRecords(op)) >= 1

}