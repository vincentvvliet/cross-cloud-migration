module RedisQueue {
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
}