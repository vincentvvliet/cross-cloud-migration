module BaseKV {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    pure val KV_MAX_SIZE: int = 20

    // KV State
    var kv: int -> int

    // Init
    action initKV = all {
        kv' = Set().setToMap()
    }

    // TODO: check old actions
    // --- Actions ---
    // action put_action(k: Key, v: Value): bool = all {
    //     if (KEYS.contains(k) and VALUES.contains(v))  all {
    //         store' = store.put(k, v),
    //         if (history.keys().contains(k)) {
    //             history' = history.put(k, history.get(k).union(Set(v)))
    //         }
    //         else {
    //             history' = history.put(k, Set(v))
    //         }
    //     }
    //     else all {
    //         store' = store,
    //         history' = history
    //     }
    // }

    // action delete(k: Key): bool = {
    //     if (store.keys().contains(k)) all {
    //         store' = mapRemove(store, k),
    //         history' = history
    //     }
    //     else all {
    //         store' = store,
    //         history' = history
    //     }
    // }

    // // A get action does not change state (pure read)
    // action get_action(k: str): bool = {
    //     if (store.keys().contains(k)) all {
    //         store' = store,
    //         history' = history
    //     }   
    //     else all {
    //         store' = store,
    //         history' = history
    //         // return expression, but add failure since key doesn't exist
    //     }   
    // }

    // KV Invariants
    val kv_no_negative_size =
        size(kv.keys()) >= 0

    val kv_max_size =
        size(kv.keys()) <= KV_MAX_SIZE

    val keys_within_domain =
        kv.keys().forall(k => VALUES.contains(k))

    val values_within_domain =
        kv.keys().forall(k =>
            VALUES.contains(kv.getOrElse(k, -1))
        )

    val map_is_functional =
        kv.keys().forall(k =>
            size(mapToSet(kv).filter(e => e._1 == k)) <= 1
        )

    val kv_invariants = all {
        kv_no_negative_size,
        kv_max_size,
        keys_within_domain,
        values_within_domain,
        map_is_functional,
    }
}
