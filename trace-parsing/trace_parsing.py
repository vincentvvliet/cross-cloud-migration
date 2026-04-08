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


def make_feedback(error_type, **kwargs):
    return {"error_type": error_type, **kwargs}


# -----------------------------
# INVARIANTS
# -----------------------------


def invariant_no_conflicts(state):
    """Same key should not have different values across replicas."""
    seen = {}

    for replica_id, replica in state.items():
        for k, v in replica.items():
            if k in seen and seen[k]["value"] != v:
                return False, {
                    "key": k,
                    "conflict": {
                        "replica_1": seen[k]["replica"],
                        "value_1": seen[k]["value"],
                        "replica_2": replica_id,
                        "value_2": v,
                    },
                }
            seen[k] = {"value": v, "replica": replica_id}

    return True, None


def invariant_kv_backed_by_history(state, history):
    writes = {(m["key"], m["value"]) for m in history}

    for replica_id, replica_map in state.items():
        for k, v in replica_map.items():
            if (k, v) not in writes:
                return False, {
                    "replica": replica_id,
                    "key": k,
                    "value": v,
                    "history_writes": list(writes),
                }

    return True, None


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
        return True, None

    for r in prev:
        if not prev[r].items() <= curr[r].items():
            return False, {"replica": r, "prev": prev[r], "curr": curr[r]}

    return True, None


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

    for replica_id, replica_map in state.items():
        for k, v in replica_map.items():
            if k in lw and lw[k] != v:
                return False, {
                    "replica": replica_id,
                    "key": k,
                    "expected": lw[k],
                    "actual": v,
                }

    return True, None


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

            # 1. Infer transitions
            added, removed = diff_history(prev["history"], curr["history"])
            kv_changes = diff_kv(prev["kv"], curr["kv"])

            # APPLY OPERATIONS
            for m in added:
                key = m["key"]
                value = m["value"]

                for r in curr["kv"]:
                    if key in curr["kv"][r] and key not in prev["kv"].get(r, {}):
                        self.redis.write(r, key, value)
                        last_action = "write"

            if not added and not removed and kv_changes:
                for op, r, k, v in kv_changes:
                    if op == "delete":
                        self.redis.delete(r, k)
                        last_action = "delete"
                    elif op == "write":
                        self.redis.write(r, k, v)
                        last_action = "sync"

            if not added and not removed and not kv_changes:
                last_action = "read"

            # 2. Compare state
            expected = curr["kv"]
            redis_state = normalize_state(self.redis.get_state(), expected.keys())

            if redis_state != expected:
                return make_feedback(
                    "state_mismatch", step=i, expected=expected, actual=redis_state
                )

            # 3. Invariants

            ok, details = invariant_no_conflicts(redis_state)
            if not ok:
                return make_feedback(
                    "invariant_violation",
                    step=i,
                    invariant="no_conflicts",
                    details=details,
                )

            ok, details = invariant_kv_backed_by_history(redis_state, curr["history"])
            if not ok:
                return make_feedback(
                    "invariant_violation",
                    step=i,
                    invariant="kv_backed_by_history",
                    details=details,
                )

            ok, details = invariant_sync_only_adds(prev["kv"], curr["kv"], last_action)
            if not ok:
                return make_feedback(
                    "invariant_violation",
                    step=i,
                    invariant="sync_only_adds",
                    details=details,
                )

            ok, details = invariant_last_write_visible(redis_state, curr["lastWrite"])
            if not ok:
                return make_feedback(
                    "invariant_violation",
                    step=i,
                    invariant="last_write_visible",
                    details=details,
                )

            prev = curr

        return {"status": "success"}


# -----------------------------
# MAIN
# -----------------------------

if __name__ == "__main__":
    trace = load_itf_trace("trace-parsing/traces/trace.itf.json")
    runner = TraceRunner(trace)
    result = runner.run()

    print(json.dumps(result, indent=2))
