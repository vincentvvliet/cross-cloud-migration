
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {
    import commonSpells.* from "../../helper/commonSpells"
    import basicSpells.* from "../../helper/basicSpells"
    import Base.* from "../../temp/quint/base"

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
