module Types {
    pure val VALUES: Set[int] = 0.to(100)

    type Message = {
        id: int,
        key: int,
        value: int
    }
}
