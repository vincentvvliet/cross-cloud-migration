module BaseKV {
    import Types.* from "../common/types"
    import commonSpells.* from "../common/commonSpells"
    import basicSpells.* from "../common/basicSpells"

    pure val KV_MAX_SIZE: int = 20
    type Client = int
    type Replica = int

    // KV State
    var kv: Replica -> (int -> int)        // per-replica key-value maps
    var lastWrite: Client -> (int -> int)  // client’s most recent writes
    var visibleReplicas: Client -> Set[Replica]

    // kv[r] is replica r’s local state
    // lastWrite[c][k] = v means client c last wrote (k,v)
    // visibleReplicas[c] models which replicas a client can read from


    // Init
    action initKV = all {
        kv' = Map(-1 -> Set().setToMap()),
        lastWrite' = Map(-1 -> Set().setToMap()),
        visibleReplicas' = Map(-1 -> Set())
    }

    // TODO: check old actions
    // --- Actions ---
    action write(c: Client, k: int, v: int, r: Replica): bool = all {
        kv' = kv.put(r, kv.get(r).put(k, v)),
        lastWrite' = lastWrite.put(c, lastWrite.get(c).put(k, v)),
        visibleReplicas' = visibleReplicas
    }

    // Does not change state, but models a read operation that returns a value
    action read(c: Client, k: int, r: Replica, out: int): bool = all {
        require(r.in(visibleReplicas.get(c))),
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        // out = kv[r].getOrElse(k, -1),
    }

    action replicate(src: Replica, dst: Replica, k: int): bool = all {
        kv' = kv.put(dst, kv.get(dst).put(k, kv.get(src).getOrElse(k, -1))),
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
    }

    // TODO: decide how to define kvView in the presence of multiple replicas. For now, we just take the view of one replica (the first one in the set of replicas).
    // TODO: refactor
    // pure def kvView: int -> int = kv.get(REPLICAS.convertToList().head())

    val kv_flat = kv.get(REPLICAS.convertToList().head())

    // KV Invariants
    val kv_no_negative_size =
        size(kv_flat.keys()) >= 0

    val kv_max_size =
        size(kv_flat.keys()) <= KV_MAX_SIZE

    val keys_within_domain =
        kv_flat.keys().forall(k => VALUES.contains(k))

    val values_within_domain =
        kv_flat.keys().forall(k =>
            VALUES.contains(kv_flat.getOrElse(k, -1))
        )

    val map_is_functional =
        kv_flat.keys().forall(k =>
            size(mapToSet(kv_flat).filter(e => e._1 == k)) <= 1
        )

    val kv_invariants = all {
        kv_no_negative_size,
        kv_max_size,
        keys_within_domain,
        values_within_domain,
        map_is_functional,
    }

    // val values_within_domain =
    //     // Due to replicas, kv maps to a map of maps, so we need to check all values in all inner maps are within the domain.
    //     kv.keys().forall(k =>
    //         val curr_kv = kv.get(k)
    //         curr_kv.keys().forall(k =>
    //             VALUES.contains(curr_kv.getOrElse(k, -1))
    //         )
    //     )

}
