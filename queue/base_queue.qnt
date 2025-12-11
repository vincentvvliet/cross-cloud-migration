module QueueBase {
    // Abstract state
    type Message = int
    var queue: List[Message]
    var delivered: List[Message]
    var pendingAck: Set[Message] // delivered but not yet acknowledged
    var acked: Set[Message] // acknowledged deliveries


    // Global variables
    pure val QUEUE = [1,2,3,4,5]
    pure val MAX_ITEMS = 5
    pure val AT_MOST_DELIVERY: Set[str] = Set("redis") // TODO: append more systems
    pure val EXACTLY_ONCE_DELIVERY: Set[str] = Set("kafka", "sqs_fifo") // TODO: append more systems
    pure val AT_LEAST_ONCE_DELIVERY: Set[str] = Set("kafka", "sqs_fifo") // TODO: append more systems

    // Helper functions
    def isEmpty(q: List[Message]): bool =
        length(q) == 0

    def convertToSet(list: List[Message]): Set[Message] = 
        (list.foldl(Set(), (acc, x) => acc.union(Set(x))))

    def containsMessage(list: List[Message], m: Message): bool = 
        ((convertToSet(delivered)).contains(m))

    pure def listContains(__list: List[Message], __elem: Message): bool = 
        __list.foldl(
        false, 
        (__acc, __i) => __acc or __i == __elem)

    // Actions
    action queueUnchanged = all {
        delivered' = delivered,
        queue' = queue
    }

    action enqueue(m: Message, system: str): bool = all {
        if (length(queue) == MAX_ITEMS) 
            // Cannot enqueue, full 
            queueUnchanged
        else all {
            delivered' = delivered,
            queue' = queue.append(m)
        }
    }
        
    action dequeue(system: str): bool = {
        if (isEmpty(queue)) all {
            queueUnchanged
        }
        else {
            if (system.in(AT_MOST_DELIVERY)) { // TODO: update AT_MOST_DELIVERY via configs
                if (not (containsMessage(delivered, head(queue)))) all {
                    // When dequeing, message delivered
                    delivered' = delivered.append(head(queue)),
                    // remove head from queue
                    queue' = tail(queue)
                }
                else all {
                    delivered' = delivered,
                    queue' = tail(queue)
                }
            } else all {
                // Not at-most-delivery, normal dequeue
                delivered' = delivered.append(head(queue)),
                queue' = tail(queue)
            }
        }
    }

    action ack(m: Message): bool = {
        if (m.in(pendingAck)) all {
            pendingAck' = pendingAck.filter(x => x == m),
            acked' = acked.union(Set(m)),
            delivered' = delivered,
            queue' = queue
        }
        else all {
            pendingAck' = pendingAck,
            acked' = acked,
            queueUnchanged,
        }
    }

    action init = all {
        // At the initial state, all balances are zero
        queue' = QUEUE,
        delivered' = []
    }

    // Invariants
    val no_negative_size = length(queue) >= 0
    val max_size = length(queue) <= MAX_ITEMS

    // Invariants todo:
    // Safety -> no acknowledged message lost
    // Safety -> Messages appear in FIFO order (if guarantees)
    // Liveness -> every enqueued message can eventually be dequeued
}