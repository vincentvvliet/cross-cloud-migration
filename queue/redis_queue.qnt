module RedisQueue {
    import QueueBase.* from "./base_queue"

    // Crash: Redis process dies, memory wiped
    action crash = all {
        queue' = [],
        delivered' = delivered
    }

    // Peek: return head without dequeing. Since this does not update queue, no-op
    action peek = {
        queueUnchanged
    }

    action step = {
        nondet m = 1.to(10).oneOf()
        any {
            enqueue(m, "redis"),
            dequeue("redis"),
            crash
        }
    }

    // Redis-specific Invariants
    // At-most-once: 'delivered' contains no duplicates
    val at_most_once_delivery =
        convertToSet(delivered).size() == delivered.length()

    val redis_invariants = all {
        max_size,
        no_negative_size,
        at_most_once_delivery,
    }
}