module Redis {
    import BaseQueue.* from "../queue/baseQueue"

    // Crash: Redis process dies, memory wiped
    action crash = all {
        queue' = Set(),
        delivered' = delivered
    }

    // TODO: Redis-specific logic
}