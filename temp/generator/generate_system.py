def unchanged_assignments(all_state, owned_state):
    return [
        f"{v}' = {v}"
        for v in all_state
        if v not in owned_state
    ]

def generate_composite_action(name, arity, owned, all_state, composite):
    if not composite:
        return ""
        
    args = "m: Message" if arity == 1 else ""
    call = f"{name}(m)" if arity == 1 else f"{name}()"

    lines = []
    lines.append(f"    action composite{name.capitalize()}({args}): bool = all {{")
    lines.append(f"        {call},")

    for v in all_state:
        if v not in owned:
            lines.append(f"        {v}' = {v},")

    lines[-1] = lines[-1].rstrip(",")
    lines.append("    }")
    return "\n".join(lines)


def generate_step(actions):
    calls = []

    for act in actions:
        # Decide function name
        if act["composite"]:
            fn = f"composite{act['name'].capitalize()}"
        else:
            fn = act["name"]

        # Decide arguments
        if act["arity"] == 0:
            call = f"{fn}()"
        elif act["arity"] == 1:
            call = f"{fn}({act['input']})"
        else:
            raise ValueError(f"Unsupported arity: {act['arity']}")

        calls.append(call)

    body = ",\n            ".join(calls)

    return f"""
    // Unified Step
    action step = {{
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()

        val input: Message = {{id: id, key: k, value: v}}

        any {{
            {body}
        }}
    }}
"""



def generate_system_qnt(cfg, systems_db, out_path):
    active = cfg["systems"]


    all_state = []
    systems = [s['type'] for s in active.values()]
    systems.append(cfg["composition"]["name"])

    for s in systems:
        all_state += systems_db[s]["state"]

    lines = []
    lines.append("module System {")
    lines.append('    import Types.* from "../systems/common/types"')
    lines.append('    import GeneratedInvariants.* from "./generated_invariants"')
    lines.append("")

    # Imports
    for s in systems:
        lines.append("    " + systems_db[s]["import"])

    lines.append("")
    lines.append("    // Unified Init")
    lines.append("    action init = all {")
    for s in systems:
        lines.append(f"        {systems_db[s]['init']},")
    lines[-1] = lines[-1].rstrip(",")
    lines.append("    }")
    lines.append("")

    # Composite actions
    actions = []
    for s in systems:
        for act in systems_db[s]["actions"]:
            # TODO: refactor below as one-liner function
            state = systems_db[s]["state"]
            arity = systems_db[s]["actions"][act]["arity"]
            composite = systems_db[s]["actions"][act].get("composite", False)
            act_input = systems_db[s]["actions"][act]["input"]

            actions.append({
                "name": act,
                "arity": arity,
                "composite": composite,
                "input": act_input,
            })

            lines.append(generate_composite_action(act, arity, state, all_state, composite))

    # Step
    lines.append(generate_step(actions))

    # TODO: base invariants
    system_keys = list(cfg["systems"].keys())

    lines.append(f"""
    // Base Invariants
    val base_invariants = all {{
        {system_keys[0]}_invariants,
        {system_keys[1]}_invariants,
        composition_invariants,    
    }}   
""")

    # Full invariants
    lines.append("""
    // Full System Invariants
    val SystemCorrect =
        base_invariants and
        composition_specific_invariants and
        generated_invariants
}
""")

    with open(out_path, "w") as f:
        f.write("\n".join(lines))
