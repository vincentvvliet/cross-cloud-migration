module Types {
    pure val VALUES: Set[int] = 0.to(100)
    pure val QUEUE_MAX_SIZE: int = 20

    // Functionality without replicas is the same with a single replica that all clients can see
    pure val REPLICAS: Set[int] = 1.to(3)
    pure val CLIENTS: Set[int] = Set(1)
    pure val CONSUMERS: Set[Set[int]] = Set(Set(1))

    type Message = {
        id: int,
        key: int,
        value: int,
        client: int,
        recipients: Set[int]
    }

    type Recipient = int
}
