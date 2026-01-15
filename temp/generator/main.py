from parse_config import parse_config
from invariants import INVARIANTS
from generate_quint import generate_quint

OUTPUT = "../quint/generated_invariants.qnt"

def main():
    caps = parse_config("../config/system.yaml")

    active = [i for i in INVARIANTS if i.condition(caps)]

    quint = generate_quint(active)

    with open(OUTPUT, "w") as f:
        f.write(quint)

    print(f"Generated {len(active)} invariants")

if __name__ == "__main__":
    main()
