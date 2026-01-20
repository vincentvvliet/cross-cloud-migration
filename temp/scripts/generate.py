# TODO: check for removal

import yaml

def unchanged_assignments(all_state, owned_state):
    return [
        f"{v}' = {v}"
        for v in all_state
        if v not in owned_state
    ]
    

def generate_composite_action(name, call, owned_state, all_state):
    lines = []
    lines.append(f"action {name}(m: Message): bool = all {{")
    lines.append(f"    {call}(m),")

    for a in unchanged_assignments(all_state, owned_state):
        lines.append(f"    {a},")

    # remove trailing comma
    lines[-1] = lines[-1].rstrip(",")

    lines.append("}")
    return "\n".join(lines)


# TODO: read from systems.json
SYSTEMS = {
    "SimpleQueue": {
        "import": 'import SimpleQueue.* from "systems/queues/simple_queue"',
        "state": ["queue", "inflight", "history"],
        "actions": ["enqueue", "deliver"],
        "init": "initQueue",
    },
    "SimpleKV": {
        "import": 'import SimpleKV.* from "systems/kv/simple_kv"',
        "state": ["kv"],
        "actions": [],
        "init": "initKV",
    },
    "KVQueue": {
        "import": 'import KVQueue.* from "compositions/kv_queue"',
        "state": ["processed"],
        "actions": ["process"],
        "init": "initComposition",
    }
}

with open("config/config.yaml") as f:
    cfg = yaml.safe_load(f)

systems = ["SimpleQueue", "SimpleKV", "KVQueue"]

all_state = []
for s in systems:
    all_state += SYSTEMS[s]["state"]

lines = []
lines.append("module System {")
lines.append('    import Types.* from "systems/common/types"')
lines.append('    import GeneratedInvariants.* from "./generated_invariants"')

for s in systems:
    lines.append("    " + SYSTEMS[s]["import"])

lines.append("")
lines.append("    // Unified Init")
lines.append("    action init = all {")
for s in systems:
    lines.append(f"        {SYSTEMS[s]['init']},")
lines[-1] = lines[-1].rstrip(",")
lines.append("    }")
lines.append("")

# Composite actions
lines.append("    // Composite Actions")

lines.append(generate_composite_action(
    "compositeEnqueue",
    "enqueue",
    SYSTEMS["SimpleQueue"]["state"],
    all_state
))

lines.append("")
lines.append(generate_composite_action(
    "compositeDeliver",
    "deliver",
    SYSTEMS["SimpleQueue"]["state"],
    all_state
))

# Step
lines.append("""
    action step = {
        nondet id: int = VALUES.oneOf()
        nondet k: int = VALUES.oneOf()
        nondet v: int = VALUES.oneOf()

        val input: Message = {id: id, key: k, value: v}

        any {
            compositeEnqueue(input),
            compositeDeliver(getHead(queue)),
            process(getHead(inflight)),
        }
    }
""")

# Invariants
lines.append("""
    val base_invariants = all {
        queue_invariants,
        kv_invariants,
        composition_invariants,
    }

    val specific_invariants = all {
        composition_specific_invariants,
    }

    val SystemCorrect =
        base_invariants and
        composition_specific_invariants and
        generated_invariants
}
""")

with open("quint/system1.qnt", "w") as f:
    f.write("\n".join(lines))
