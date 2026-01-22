
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {
    import commonSpells.* from "../systems/common/commonSpells"
    import basicSpells.* from "../systems/common/basicSpells"
    import BaseQueue.* from "../systems/queue/baseQueue"
		import BaseKV.* from "../systems/kv/baseKV"
		import KVQueue.* from "../systems/compositions/kvQueue"
		import Redis.* from "../systems/queue/redis"

    val all_kv_from_queue = mapToSet(kv).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            processed.contains(m.id)
          )
        )

		val at_most_once = processed.forall(id =>
            processed.forall(other_id =>
                id == other_id or
                history.filter(m => m.id == id).size() == 1
            )
        )

		val crash_safety = // Crashes should not occur unless specified in the system model
      history.size() == queue.size() + inflight.size() + processed.size()

    val generated_invariants = all {
        all_kv_from_queue,
				at_most_once,
				crash_safety
    }

}
