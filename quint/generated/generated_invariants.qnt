
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {
    import commonSpells.* from "../systems/common/commonSpells"
    import basicSpells.* from "../systems/common/basicSpells"
    import KVQueue.* from "../systems/compositions/kvQueue"
		import Kafka.* from "../systems/queue/kafka"
		import DynamoDB.* from "../systems/kv/dynamoDB"

    val processed_from_queue = processed.forall(p => history.exists(m => m.id == p._2.id))

		val all_kv_from_queue = mapToSet(kv_view).forall(e =>
          history.exists(m =>
            m.key == e._1 and
            m.value == e._2 and
            processed.map(p => p._2.id).contains(m.id)
          )
        )

		val exactly_once = history.forall(m =>
          processed.map(p => p._2.id).contains(m.id)
            iff kv_view.getOrElse(m.key, -1) == m.value
        )

		val at_most_once = processed.forall(p =>
            processed.forall(other_p =>
                p._2.id == other_p._2.id or
                history.filter(m => m.id == p._2.id).size() == 1
            )
        )

    val generated_invariants = all {
        processed_from_queue,
				all_kv_from_queue,
				exactly_once,
				at_most_once
    }

}
