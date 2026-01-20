module SimpleKV {
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
