import json
import redis
from copy import deepcopy

# -----------------------------
# ITF PARSING
# -----------------------------


def parse_value(v):
    """Convert ITF encoding to Python ."""

    if isinstance(v, dict):
        # Special ITF encodings
        if "#bigint" in v:
            return int(v["#bigint"])

        if "#map" in v:
            return {parse_value(k): parse_value(val) for k, val in v["#map"]}

        if "#set" in v:
            return [parse_value(x) for x in v["#set"]]

        return {k: parse_value(val) for k, val in v.items()}

    elif isinstance(v, list):
        return [parse_value(x) for x in v]

    return v


def parse_state(state):
    return {k: parse_value(v) for k, v in state.items() if not k.startswith("#")}


def load_itf_trace(path):
    with open(path) as f:
        data = json.load(f)

    return [parse_state(s) for s in data["states"]]


# -----------------------------
# REDIS EXECUTION
# -----------------------------


class RedisExecutor:
    def __init__(self, initial_kv):
        self.r = redis.Redis(host="localhost", port=6379, decode_responses=True)
        self.r.flushall()

        self.replicas = list(initial_kv.keys())

        for replica in self.replicas:
            key = f"replica:{replica}"
            self.r.hset(key, "__init__", 0)
            self.r.hdel(key, "__init__")

    def write(self, replica, key, value):
        self.r.hset(f"replica:{replica}", key, value)

    def delete(self, replica, key):
        self.r.hdel(f"replica:{replica}", key)

    def get_state(self):
        result = {}
        for key in self.r.keys("replica:*"):
            replica = int(key.split(":")[1])
            result[replica] = {int(k): int(v) for k, v in self.r.hgetall(key).items()}
        return result


# -----------------------------
# TRANSITION INFERENCE
# -----------------------------


def diff_kv(prev, curr):
    changes = []

    for replica in curr:
        prev_map = prev.get(replica, {})
        curr_map = curr.get(replica, {})

        # Detect writes (new keys)
        for k, v in curr_map.items():
            if k not in prev_map:
                # Currently, see syncing as writes to new keys, but could be separate action type in the future
                changes.append(("write", replica, k, v))

        # Detect deletes
        for k in prev_map:
            if k not in curr_map:
                changes.append(("delete", replica, k, None))

    return changes


def diff_history(prev_hist, curr_hist):
    prev_ids = {m["id"] for m in prev_hist if "id" in m}
    curr_ids = {m["id"] for m in curr_hist if "id" in m}

    added = [m for m in curr_hist if m["id"] not in prev_ids]
    removed = [m for m in prev_hist if m["id"] not in curr_ids]

    return added, removed


def normalize_state(state, replicas):
    return {r: state.get(r, {}) for r in replicas}


# -----------------------------
# INVARIANTS
# -----------------------------


def invariant_no_divergent_values(state):
    """Same key should not have different values across replicas."""
    seen = {}

    for replica, kv in state.items():
        for k, v in kv.items():
            if k in seen and seen[k] != v:
                return False
            seen[k] = v

    return True


def invariant_kv_backed_by_history(state, history):
    writes = {(m["key"], m["value"]) for m in history}

    for replica_map in state.values():
        for k, v in replica_map.items():
            if (k, v) not in writes:
                return False

    return True


# def invariant_no_resurrection(prev_state, curr_state):
#     for r in prev_state:
#         prev_keys = set(prev_state[r].keys())
#         curr_keys = set(curr_state[r].keys())

#         # If a key disappeared and reappears later → violation
#         # (this needs history to fully enforce)
#     return True


def invariant_sync_only_adds(prev, curr, last_action):
    if last_action != "sync":
        # Invariant only holds if sync action was last
        return True

    for r in prev:
        if not prev[r].items() <= curr[r].items():
            return False
    return True


def invariant_eventual_convergence(state):
    # Only relevant at the end of execution.
    all_maps = list(state.values())
    print(all_maps)
    return all(m == all_maps[0] for m in all_maps)


def invariant_last_write_visible(state, last_write):
    lw = {}
    for client_map in last_write.values():
        # LastWrite contains -1 values if item has been deleted.
        filtered_map = {k: v for k, v in client_map.items() if v >= 0}
        lw.update(filtered_map)

    for replica_map in state.values():
        for k, v in replica_map.items():
            if k in lw and lw[k] != v:
                return False

    return True


def invariant_no_conflicts(state):
    seen = {}

    for replica_map in state.values():
        for k, v in replica_map.items():
            if k in seen and seen[k] != v:
                return False
            seen[k] = v

    return True


# -----------------------------
# RUNNER
# -----------------------------


class TraceRunner:
    def __init__(self, trace):
        self.trace = trace
        self.redis = RedisExecutor(trace[0]["kv"])

    def run(self):
        prev = self.trace[0]
        last_action = None

        for i, curr in enumerate(self.trace[1:], start=1):
            print(f"\n--- Step {i} ---")

            # 1. Infer transitions
            added, removed = diff_history(prev["history"], curr["history"])
            kv_changes = diff_kv(prev["kv"], curr["kv"])

            # History based: WRITE
            for m in added:
                key = m["key"]
                value = m["value"]

                # find which replica got it
                for r in curr["kv"]:
                    if key in curr["kv"][r] and key not in prev["kv"].get(r, {}):
                        print(f"WRITE detected: r={r}, key={key}, value={value}")
                        self.redis.write(r, key, value)
                        last_action = "write"

            # KV-based: DELETE OR SYNC
            if not added and not removed and kv_changes:
                for op, r, k, v in kv_changes:
                    if op == "delete":
                        print(f"DELETE detected (kv): r={r}, key={k}")
                        self.redis.delete(r, k)
                        last_action = "delete"

                    elif op == "write":
                        print(f"SYNC detected: r={r}, key={k}, value={v}")
                        self.redis.write(r, k, v)
                        last_action = "sync"

            # READ / NO-OP
            if not added and not removed and not kv_changes:
                print("READ / NO-OP")
                last_action = "read"

            # 2. Get real Redis state
            expected = curr["kv"]
            redis_state = normalize_state(self.redis.get_state(), expected.keys())

            # 3. Compare with model
            if redis_state != expected:
                print("❌ STATE MISMATCH")
                print("Expected:", expected)
                print("Got     :", redis_state)
                return

            # 4. Check invariants
            if not invariant_no_divergent_values(redis_state):
                print("❌ Invariant violated: divergent values")
                return

            if not invariant_kv_backed_by_history(redis_state, curr["history"]):
                print("❌ Invariant violated: every kv entry must come from history")
                return

            if not invariant_sync_only_adds(prev["kv"], curr["kv"], last_action):
                print("❌ Invariant violated: sync should only add items")
                return

            if not invariant_last_write_visible(redis_state, curr["lastWrite"]):
                print("❌ Invariant violated: all lastWrite values should appear in kv")
                return

            if not invariant_no_conflicts(redis_state):
                print("❌ Invariant violated: no conflicts")
                return

            print("✅ State + invariants OK")

            print("Redis state:", redis_state)

            prev = curr

        print("\n🎉 Trace successfully validated!")


# -----------------------------
# MAIN
# -----------------------------

if __name__ == "__main__":
    trace = load_itf_trace("trace-parsing/traces/trace.itf.json")
    runner = TraceRunner(trace)
    runner.run()
