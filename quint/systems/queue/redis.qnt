module Redis {
    import BaseQueue.* from "baseQueue"
    export BaseQueue.* 

    // Crash: Redis process dies, memory wiped
    action crash(): bool = all {
        queue' = Set(),
        history' = history,
        inflight' = inflight,
        delivered' = delivered,
    }
}