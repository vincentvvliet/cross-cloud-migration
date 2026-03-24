import json
import redis
from copy import deepcopy

# -----------------------------
# ITF PARSING
# -----------------------------


def parse_value(v):
    """Convert ITF encoding to Python."""
    if isinstance(v, dict):
        if "#bigint" in v:
            return int(v["#bigint"])

        if "#map" in v:
            return {parse_value(k): parse_value(val) for k, val in v["#map"]}

        if "#set" in v:
            return {parse_value(x) for x in v["#set"]}

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
    def __init__(self):
        self.r = redis.Redis(host="localhost", port=6379, decode_responses=True)
        self.r.flushall()

    def write(self, replica, key, value):
        redis_key = f"replica:{replica}"
        self.r.hset(redis_key, key, value)

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
    """Find writes between states."""
    changes = []

    for replica in curr:
        prev_map = prev.get(replica, {})
        curr_map = curr.get(replica, {})

        for k, v in curr_map.items():
            if k not in prev_map:
                # Currently, see syncing as writes to new keys, but could be separate action type in the future
                changes.append(("write", replica, k, v))

    return changes


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


def invariant_subset_of_lastwrite(state, last_write):
    """All values in kv must appear in lastWrite."""
    lw_values = set()
    for client_map in last_write.values():
        for k, v in client_map.items():
            lw_values.add((k, v))

    for replica_map in state.values():
        for k, v in replica_map.items():
            if (k, v) not in lw_values:
                return False

    return True


# -----------------------------
# RUNNER
# -----------------------------


class TraceRunner:
    def __init__(self, trace):
        self.trace = trace
        # self.redis = RedisExecutor()
        self.redis = None  # TODO: enable after syncing

    def run(self):
        prev = self.trace[0]

        for i, curr in enumerate(self.trace[1:], start=1):
            print(f"\n--- Step {i} ---")

            # 1. Infer transitions
            changes = diff_kv(prev["kv"], curr["kv"])

            if not changes:
                print("No-op (likely read)")  # TODO: handle reads properly with Redis
            else:
                for op, r, k, v in changes:
                    print(f"Executing: WRITE r={r}, key={k}, value={v}")
                    # self.redis.write(r, k, v)

            # 2. Get real Redis state
            # redis_state = self.redis.get_state()
            redis_state = deepcopy(
                curr["kv"]
            )  # TODO: replace with actual Redis state after syncing

            # 3. Compare with model
            expected = curr["kv"]
            if redis_state != expected:
                print("❌ STATE MISMATCH")
                print("Expected:", expected)
                print("Got     :", redis_state)
                return

            # 4. Check invariants
            if not invariant_no_divergent_values(redis_state):
                print("❌ Invariant violated: divergent values")
                return

            if not invariant_subset_of_lastwrite(redis_state, curr["lastWrite"]):
                print("❌ Invariant violated: not subset of lastWrite")
                return

            print("✅ State + invariants OK")

            prev = curr

        print("\n🎉 Trace successfully validated!")


# -----------------------------
# MAIN
# -----------------------------

if __name__ == "__main__":
    trace = load_itf_trace("traces/trace.itf.json")
    runner = TraceRunner(trace)
    runner.run()
