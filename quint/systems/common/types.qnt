module Types {
    pure val VALUES: Set[int] = 0.to(100)
    pure val REPLICAS: Set[int] = 1.to(2)
    pure val CLIENTS: Set[int] = 1.to(2)

    type Message = {
        id: int,
        key: int,
        value: int,
        client: int,
    }
}
