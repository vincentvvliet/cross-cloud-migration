module RedisQueue {
    import QueueBase.* from "./queue"

    // Crash: Redis process dies, memory wiped
    action crash = all {
        queue' = [],
        delivered' = delivered
    }

    action step = {
        nondet m = 1.to(5).oneOf()
        any {
            enqueue(m),
            dequeue,
            crash
        }
    }

    // Redis-specific Invariants
    // TODO
}