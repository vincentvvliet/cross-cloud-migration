module KVStoreBase {
    import commonSpells.* from "../helper/commonSpells"
    import basicSpells.* from "../helper/basicSpells"

    type Key = str
    type Value = int

    var store: Key -> Value
    var history: Key -> Set[Value]

    // Global variables
    pure val KEYS: Set[Key] = Set("a", "b", "c", "d", "e")
    pure val VALUES: Set[Value] = 0.to(100)

    // --- Actions ---
    action put_action(k: Key, v: Value): bool = all {
        if (KEYS.contains(k) and VALUES.contains(v))  all {
            store' = store.put(k, v),
            if (history.keys().contains(k)) {
                history' = history.put(k, history.get(k).union(Set(v)))
            }
            else {
                history' = history.put(k, Set(v))
            }
        }
        else all {
            store' = store,
            history' = history
        }
    }

    action delete(k: Key): bool = {
        if (store.keys().contains(k)) all {
            store' = mapRemove(store, k),
            history' = history
        }
        else all {
            store' = store,
            history' = history
        }
    }

    // A get action does not change state (pure read)
    action get_action(k: str): bool = {
        if (store.keys().contains(k)) all {
            store' = store,
            history' = history
        }   
        else all {
            store' = store,
            history' = history
            // return expression, but add failure since key doesn't exist
        }   
    }

    action init = {
        nondet v1: Value = VALUES.oneOf()
        nondet v2: Value = VALUES.oneOf()
        nondet v3: Value = VALUES.oneOf()
        all {
            store' = Map("a" -> v1, "b" -> v2, "c" -> v3),
            history' = Map("a" -> Set(v1), "b" -> Set(v2), "c" -> Set(v3))
        }
    }

    // Invariants
    val no_negative_size = size(store.keys()) >= 0
    val max_size = size(store.keys()) <= KEYS.size()

    val keys_within_domain = store.keys().forall(k => KEYS.contains(k))
    val values_within_domain = store.keys().forall(k => VALUES.contains(store.get(k)))
    val map_is_functional = store.keys().forall(k => size(mapToSet(store).filter(kk => kk._1 == k)) <= 1)
    val no_lost_updates = store.keys().forall(k => history.get(k).contains(store.get(k)))

    val base_invariants = all {
        max_size,
        no_negative_size,
        keys_within_domain,
        values_within_domain,
        map_is_functional,
        no_lost_updates,
        // TODO: all values have been written by put
    } 
}