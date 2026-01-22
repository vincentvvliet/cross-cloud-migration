from invariants import Invariant

def generate_quint(invariants: List[Invariant], imports) -> str:
    """
    Generate the Quint module containing the given invariants.
    """
    imports_block = "\n\t\t".join(imports)

    defs = "\n\n\t\t".join(
        f"val {inv.name} = {inv.quint.strip()}"
        for inv in invariants
    )

    body = ",\n\t\t\t\t".join(inv.name for inv in invariants)

    return f"""
// AUTO-GENERATED — DO NOT EDIT

module GeneratedInvariants {{
    import commonSpells.* from "../systems/common/commonSpells"
    import basicSpells.* from "../systems/common/basicSpells"
    {imports_block}

    {defs}

    val generated_invariants = all {{
        {body}
    }}

}}
"""
