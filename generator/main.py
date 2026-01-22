from parse_config import parse_config
from invariants import INVARIANTS, satisfies
from load_systems import load_systems
from generate_invariants import generate_quint
from generate_system import generate_system_qnt


def main():
    # TODO: enforce types when parsing config
    # TODO: enforce exactly 2 systems
    # TODO: seperate systems from composite systems
    caps = parse_config("config/config.yaml")
    systems_db = load_systems("config/systems.json")

    active = [inv for inv in INVARIANTS if satisfies(caps["systems"], inv.requires)]

    imports = [systems_db[s]["import"] for s in systems_db]

    quint = generate_quint(active, imports)

    with open("quint/generated/generated_invariants.qnt", "w") as f:
        f.write(quint)

    print(f"Generated {len(active)} invariants")

    generate_system_qnt(caps, systems_db, "quint/generated/system.qnt")

    print(f"Generated system.qnt")


if __name__ == "__main__":
    main()
