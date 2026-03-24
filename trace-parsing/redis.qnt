module BaseKV {
    import Types.* from "../quint/systems/common/types"
    import commonSpells.* from "../quint/systems/common/commonSpells"
    import basicSpells.* from "../quint/systems/common/basicSpells"

    pure val KV_MAX_SIZE: int = 20
    type Client = int
    type Replica = int

    // KV State
    var history: Set[Message]               // Written Messages
    var kv: Replica -> (int -> int)        // per-replica key-value maps
    var lastWrite: Client -> (int -> int)  // client’s most recent writes
    var visibleReplicas: Client -> Set[Replica] // TODO: handle visibility of replicas to clients

    // kv[r] is replica r’s local state
    // lastWrite[c][k] = v means client c last wrote (k,v)
    // visibleReplicas[c] models which replicas a client can read from


    // Init
    action initKV = all {
        // Each replica starts with empty key-value map
        kv' = REPLICAS.map(r => (r, Set().setToMap())).setToMap(),
        
        // Each client starts with empty lastWrite map
        lastWrite' = CLIENTS.map(c => (c, Set().setToMap())).setToMap(),

        // Each client initially can see all replicas
        visibleReplicas' = CLIENTS.map(c => (c, REPLICAS)).setToMap(),

        history' = Set(),
    }

    action init = all {
        initKV
    }

    // --- Actions ---
    // For combined system, writing is handled in kvQueue.process()
    action write(m: Message, r: Replica): bool = all {
        require(r.in(kv.keys())),
        require(lastWrite.values().forall(clientMap => not(clientMap.keys().contains(m.key)))), // Unique key
        
        kv' = kv.put(r, kv.get(r).put(m.key, m.value)),
        history' = history.union(Set(m)),
        lastWrite' = lastWrite.put(m.client, lastWrite.get(m.client).put(m.key, m.value)),
        visibleReplicas' = visibleReplicas
    }

    // Does not change state, but models a read operation that returns a value
    action read(m: Message, r: Replica, out: int): bool = all {
        require(r.in(visibleReplicas.get(m.client))),
        kv' = kv,
        lastWrite' = lastWrite,
        history' = history,
        visibleReplicas' = visibleReplicas,
        // out = kv.get(r).getOrElse(m.key, -1),
    }

    action sync(src: Replica, dst: Replica): bool = all {
        require(src.in(kv.keys()) and dst.in(kv.keys())),
        // Note: this is a simple sync that only copies over keys that are not already present at dst. More complex syncs could involve conflict resolution, timestamps, etc.
        kv' = kv.get(src).keys()
            .filter(k => not (k.in(kv.get(dst).keys()))) // Only get keys not already in dst to avoid overwriting at dst
            .fold(kv, (acc, k) => acc.put(dst, acc.get(dst).put(k, kv.get(src).get(k)))), 
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        history' = history,
    }

    action delete(m: Message, r: Replica): bool = all {
        require(r.in(kv.keys())),

        kv' = kv.put(r, kv.get(r).mapRemove(m.key)),
        lastWrite' = lastWrite.put(
            m.client,
            lastWrite.get(m.client).put(m.key, -1)
        ),
        visibleReplicas' = visibleReplicas,
        history' = history.setRemove(m),
    }

    action allUnchanged = all {
        kv' = kv,
        lastWrite' = lastWrite,
        visibleReplicas' = visibleReplicas,
        history' = history
    }
    
    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()
        nondet client: int = CLIENTS.oneOf()
        nondet replica: int = REPLICAS.oneOf()
        nondet recipients: Set[int] = CONSUMERS.oneOf()
        nondet dst: int = REPLICAS.filter(r => r != replica).oneOf()
        
        val input: Message = {id: id, key: k, value: v, client: client, recipients: recipients}
        val keySet: Set[int] = kv.get(replica).keys()

        any {
            write(input, replica),
            read(input, replica, -1),
            sync(replica, dst),
            match getHead(keySet) {
                | Some(k) => match history.find(h => h.key == k) {
                    | Some(m) => delete(m, replica)
                    | None => allUnchanged
                }
                | None => allUnchanged
            }
        }
    }


    val kv_view: int -> int =
        // Convert each inner map to a set of (key, value) pairs, then flatten
        kv.values().map(v => v.mapToSet()).flatten().setToMap() 

    // KV Invariants
    val kv_no_negative_size =
        size(kv_view.keys()) >= 0

    val kv_max_size =
        size(kv_view.keys()) <= KV_MAX_SIZE

    val keys_within_domain =
        kv_view.keys().forall(k => VALUES.contains(k))

    val values_within_domain =
        kv_view.keys().forall(k =>
            VALUES.contains(kv_view.getOrElse(k, -1))
        )

    val map_is_functional =
        kv_view.keys().forall(k =>
            size(mapToSet(kv_view).filter(e => e._1 == k)) <= 1
        )
    
    // val all_kv_values_in_last_writes = 
    //     mapToSet(kv_view).forall(e =>
    //         lastWrite.values().exists(m => m.getOrElse(e._1, -1) == e._2)
    //     )

    val kv_invariants = all {
        kv_no_negative_size,
        kv_max_size,
        keys_within_domain,
        values_within_domain,
        map_is_functional,
        // all_kv_values_in_last_writes
    }
}
