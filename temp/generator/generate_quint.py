from invariants import Invariant

def generate_quint(invariants: list[Invariant]) -> str:
    body = ",\n".join(inv.name for inv in invariants)

    defs = "\n\n".join(
        f"val {inv.name} = {inv.quint.strip()}"
        for inv in invariants
    )

    return f"""
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {{
    import commonSpells.* from "../../helper/commonSpells"
    import basicSpells.* from "../../helper/basicSpells"
    import Base.* from "../../temp/quint/base"

{defs}

val generated_invariants = all {{
  {body}
}}

}}
"""
