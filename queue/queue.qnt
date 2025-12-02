// TODO:
// create subsystems that import shared actions and types from QueueBase
// each subsystem has own defined step to support own actions
// each subsystem has shared invariants + own invariants


module QueueBase {
    // Abstract state
    type Message = int
    var queue: List[Message]

    // Global variables
    pure val QUEUE = [1,2,3,4,5]
    pure val MAX_ITEMS = 5

    // Actions
    def isEmpty(q: List[Message]): bool =
        length(q) == 0

    // Actions
    action enqueue(m: Message): bool = {
        if (length(queue) == MAX_ITEMS)
            // queue full, no-op and remove it
            queue' = queue
        else
            queue' = queue.append(m)
    }
        
    action dequeue = {
        if (isEmpty(queue))
            // no-op
            queue' = queue
        else
            // return head and remove it
            queue' = tail(queue)
    }

    action init = {
        // At the initial state, all balances are zero
        queue' = QUEUE
    }

    // action step = {
    //     nondet m = 1.to(5).oneOf()
    //     any {
    //         enqueue(m),
    //         dequeue
    //     }
    // }    

    // Invariants
    val no_negative_size = length(queue) >= 0
    val max_size = length(queue) <= MAX_ITEMS

    // action recover = {

    // }

    // action replicate = {
        
    // }

    // Invariants todo:
    // Safety -> no acknowledged message lost
    // Safety -> Messages appear in FIFO order (if guarantees)
    // Liveness -> every enqueued message can eventually be dequeued
}