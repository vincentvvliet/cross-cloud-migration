module QueueBase {
    // Abstract state
    type Message = int
    var queue: List[Message]

    // Initial input
    pure val QUEUE = [1,2,3,4,5]

    // Actions
    action enqueue(m: Message): bool = {
        queue' = queue.append(m)
    }
        
    action dequeue = {
        if (length(queue) > 0)
            // return head and remove it
            queue' = tail(queue)
        else
            // no-op
            queue' = queue
    }

    action init = {
        // At the initial state, all balances are zero
        queue' = QUEUE
    }

    action step = any {
        nondet m = 1.to(5).oneOf()
        enqueue(m),
        dequeue
    }
        
    
    // Invariant: no negative size (toy example)
    val no_negative_size = length(queue) >= 0
}
