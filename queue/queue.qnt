module RedisQueue {
    import QueueBase.* from "./base_queue"

    action step = {
        nondet m = 1.to(10).oneOf()
        any {
            enqueue(m, "base"),
            dequeue("base"),
        }
    }
}