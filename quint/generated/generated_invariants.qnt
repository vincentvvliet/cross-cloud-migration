
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {
    import commonSpells.* from "../systems/common/commonSpells"
    import basicSpells.* from "../systems/common/basicSpells"
    import BaseQueue.* from "../systems/queue/baseQueue"
		import BaseKV.* from "../systems/kv/baseKV"
		import KVQueue.* from "../systems/compositions/kvQueue"

    val processed_from_queue = processed.forall(id => history.exists(m => m.id == id))

		val all_kv_from_queue = mapToSet(kv).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            processed.contains(m.id)
          )
        )

		val exactly_once = history.forall(m =>
        processed.contains(m.id)
          iff kv.getOrElse(m.key, -1) == m.value
      )

    val generated_invariants = all {
        processed_from_queue,
				all_kv_from_queue,
				exactly_once
    }

}
