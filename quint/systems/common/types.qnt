module Types {
    pure val VALUES: Set[int] = 0.to(100)
    pure val QUEUE_MAX_SIZE: int = 20

    // Functionality without replicas is the same with a single replica that all clients can see
    pure val REPLICAS: Set[int] = 1.to(2)
    pure val CLIENTS: Set[int] = 1.to(2)
    pure val CONSUMERS: Set[Set[int]] = Set(Set(1))

    // TODO: implement ordering guarantees Sync before then FIFO (global)
    // 0: no ordering, 1: FIFO, 2: total ordering
    pure val ORDERING_MODE: int = FIFO
    // 0: at most once, 1: at least once, 2: exactly once
    pure val DELIVERY_MODE: int = AT_MOST_ONCE

    pure val AT_MOST_ONCE = 0
    pure val AT_LEAST_ONCE = 1
    pure val EXACTLY_ONCE = 2

    pure val FIFO = 0
    pure val UNORDERED = 1

    pure val CONSISTENCY_MODE: int = STRONG
    pure val IDEMPOTENT_WRITES: bool = true
    pure val CONDITIONAL_WRITES: bool = true

    pure val EVENTUAL = 0
    pure val STRONG = 1

    type Message = {
        id: int,
        key: int,
        value: int,
        client: int,
        recipients: Set[int]
    }

    type Recipient = int
}
