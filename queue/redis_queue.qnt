module RedisQueue {
    import QueueBase.* from "./base_queue"

    // Crash: Redis process dies, memory wiped
    action crash = all {
        queue' = [],
        delivered' = delivered
    }

    action step = {
        nondet m = 1.to(10).oneOf()
        any {
            enqueue(m),
            dequeue,
            crash
        }
    }

    // Redis-specific Invariants
    // TODO
}