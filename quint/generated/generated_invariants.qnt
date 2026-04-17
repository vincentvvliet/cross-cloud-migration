
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {
    import commonSpells.* from "../systems/common/commonSpells"
    import basicSpells.* from "../systems/common/basicSpells"
    import KVQueue.* from "../systems/compositions/kvQueue"
		import BaseQueue.* from "../systems/queue/baseQueue"
		import BaseKV.* from "../systems/kv/baseKV"

    val processed_from_queue = convertToSet(processed).forall(p => history.exists(m => m.id == p._2.id))

		val no_double_processing = convertToSet(processed).forall(p =>
            size(history.filter(m => m.id == p._2.id)) == 1
        )

		val all_kv_from_queue = mapToSet(kv_view).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            convertToSet(processed).map(p => p._2.id).contains(m.id)
          )
        )

		val exactly_once = history.forall(m =>
          convertToSet(processed).map(p => p._2.id).contains(m.id)
            iff kv_view.getOrElse(m.key, -1) == m.value
        )

		val at_most_once = convertToSet(processed).forall(p =>
            convertToSet(processed).forall(other_p =>
                p._2.id == other_p._2.id or
                history.filter(m => m.id == p._2.id).size() == 1
            )
        )

    val generated_invariants = all {
        processed_from_queue,
				no_double_processing,
				all_kv_from_queue,
				exactly_once,
				at_most_once
    }

}
