from function_signature import SIGNATURES

replicas = False
pub_sub = False
broadcast = False  # TODO: support broadcast as well


def unchanged_assignments(all_state, owned_state):
    """
    Generate unchanged assignments for state variables not owned by the action.
    """
    return [f"{v}' = {v}" for v in all_state if v not in owned_state]


def generate_composite_action(name, arg_type, owned, all_state, composite):
    """
    Generate a composite action if specified.
    """
    if not composite:
        return ""

    signature = SIGNATURES[arg_type]  # e.g. "msg_replica" or "sync"
    args = signature.args
    call = signature.call(name)

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
        fn = f"composite{act['name'].capitalize()}" if act["composite"] else act["name"]
        src = act.get("input")

        if act["arg_type"] == "crash":
            calls.append(fn)
            continue

        # direct input message
        if src == "input":
            calls.append(f"{fn}(input)")
            continue

        # state source
        if src:
            if src.startswith("inflight"):
                src = src.split(",")[0]
                action_call = f"{fn}(m._2, replica)"
            else:
                action_call = f"{fn}(m)"

            calls.append(
                f"""match getHead({src}) {{
                | Some(m) => {action_call}
                | None => allUnchanged
            }}"""
            )
            continue

        raise ValueError(f"Unsupported input source: {src}")

    body = ",\n            ".join(calls)

    return f"""
    // Unified Step
    action step = {{
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()
        nondet client: int = CLIENTS.oneOf()
        nondet replica: int = REPLICAS.oneOf()
        nondet recipients: Set[int] = CONSUMERS.oneOf()
        {"nondet dst: int = REPLICAS.filter(r => r != replica).oneOf()" if replicas else ""}

        val input: Message = {{id: id, key: k, value: v, client: client, recipients: recipients}}

        any {{
            {body}
        }}
    }}
"""


def handleTypesQuint():
    """
    Handle the case where replicas are used in the system.
    """
    with open("quint/systems/common/types.qnt", "r") as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        if line.startswith("    pure val REPLICAS: Set[int]"):
            lines[i] = (
                f"    pure val REPLICAS: Set[int] = {"1.to(2)" if replicas else "Set(1)"}\n"
            )
        elif line.startswith("    pure val CLIENTS: Set[int]"):
            lines[i] = (
                f"    pure val CLIENTS: Set[int] = {"1.to(2)" if replicas else "Set(1)"}\n"
            )
        elif line.startswith("    pure val CONSUMERS:"):
            print(pub_sub)
            lines[i] = (
                f"    pure val CONSUMERS: Set[Set[int]] = {"1.to(3).powerset().filter(r => not(r.size() > 1))" if pub_sub else "Set(Set(1))"}\n"
            )
    with open("quint/systems/common/types.qnt", "w") as f:
        f.writelines(lines)
        f.close()


def generate_system_qnt(cfg, systems_db, out_path):
    global replicas, pub_sub
    """
    Generate the system QNT file based on the configuration and systems database.
    """
    active = cfg["systems"]

    # Use of replicas
    replicas = cfg["systems"]["kv"]["replicas"]

    all_state = []
    systems = [s["type"] for s in active.values()]
    systems.append(cfg["composition"]["name"])

    # Check queue type
    pub_sub = any(systems_db[s]["type"].startswith("queue_pubsub") for s in systems)
    handleTypesQuint()

    for s in systems:
        all_state += systems_db[s]["state"]

    lines = []
    lines.append("module System {")
    lines.append('    import Types.* from "../systems/common/types"')
    lines.append('    import basicSpells.* from "../systems/common/basicSpells"')
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
            arg_type = systems_db[s]["actions"][act]["arg_type"]
            composite = systems_db[s]["actions"][act].get("composite", False)
            act_input = systems_db[s]["actions"][act]["input"]

            if act == "sync" and not replicas:
                # Do not allow sync action if replicas are not used
                continue

            actions.append(
                {
                    "name": act,
                    "arg_type": arg_type,
                    "composite": composite,
                    "input": act_input,
                }
            )

            lines.append(
                generate_composite_action(act, arg_type, state, all_state, composite)
            )

    # Step
    lines.append(generate_step(actions))

    # Base invariants
    system_keys = list(cfg["systems"].keys())

    lines.append(
        f"""
    // Base Invariants
    val base_invariants = all {{
        {system_keys[0]}_invariants,
        {system_keys[1]}_invariants,
        composition_invariants,    
    }}   
"""
    )

    # Full invariants
    lines.append(
        """
    // Full System Invariants
    val SystemCorrect =
        base_invariants and
        composition_specific_invariants and
        generated_invariants
}
"""
    )

    with open(out_path, "w") as f:
        f.write("\n".join(lines))
