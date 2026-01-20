from parse_config import parse_config
from invariants import INVARIANTS
from systems import load_systems
from generate_invariants import generate_quint
from generate_system import generate_system_qnt

from capabilities import SystemCaps, Delivery, Consistency

def main():
    caps = parse_config("config/config.yaml")
    systems_db = load_systems("config/systems.json")

    c = caps['systems']

    active_invariants = [i for i in INVARIANTS if i.condition(caps['systems'])]

    imports = [
        systems_db[s]["import"]
        for s in systems_db
    ]

    quint = generate_quint(active_invariants, imports)

    with open("quint/generated/generated_invariants.qnt", "w") as f:
        f.write(quint)

    print(f"Generated {len(active_invariants)} invariants")

    generate_system_qnt(caps, systems_db, "quint/generated/system.qnt")

    print(f"Generated system.qnt")

if __name__ == "__main__":
    main()