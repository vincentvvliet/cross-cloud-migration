import subprocess
import json
import os
from datetime import datetime
from openai import OpenAI

# -----------------------------
# CONFIG
# -----------------------------

MODEL = (
    "gpt-4o-mini"  # TODO: Determine which model to use based on experiment condition
)
MAX_ITERS = 15
USE_SPEC = True  # toggle experiment condition

client = OpenAI()

# -----------------------------
# PROMPTS
# -----------------------------

SYSTEM_PROMPT = """
You are an expert distributed systems engineer.

Your task is to implement a key-value store that satisfies correctness invariants.

STRICT RULES:
- Only output the full kv_store.py file
- No explanations
- Do not change function signatures
- No external dependencies
- Deterministic behavior only
"""

INIT_PROMPT_WITH_SPEC = """
Implement a distributed key-value store with the following properties:

PROPERTIES:
- Multiple replicas maintain key-value maps
- Writes insert/update values at a replica
- Deletes remove keys from a replica
- Sync operations propagate values between replicas
- Replicas should not diverge (no conflicting values)
- Values must originate from history
- Sync only adds data
- Latest write must be visible

INTERFACE:

class KVStore:
    def __init__(self, replicas): ...
    def write(self, replica, key, value): ...
    def delete(self, replica, key): ...
    def get_state(self): ...

Return only the full kv_store.py file.
"""

INIT_PROMPT_NO_SPEC = """
Implement a distributed key-value store with multiple replicas.

Each replica should support writes, deletes, and returning state.

INTERFACE:

class KVStore:
    def __init__(self, replicas): ...
    def write(self, replica, key, value): ...
    def delete(self, replica, key): ...
    def get_state(self): ...

Return only the full kv_store.py file.
"""

ITER_PROMPT_TEMPLATE = """
The current implementation failed verification.

FEEDBACK:
{feedback}

CURRENT IMPLEMENTATION:
{code}

Fix the implementation so that it satisfies all invariants.
Make minimal necessary changes.

Return only the full kv_store.py file.
"""

# -----------------------------
# LLM CALL
# -----------------------------


def call_llm(messages):
    response = client.chat.completions.create(
        model=MODEL, messages=messages, temperature=0
    )
    return response.choices[0].message.content


# -----------------------------
# TRACE RUNNER
# -----------------------------


def run_trace():
    result = subprocess.run(
        ["python", "trace_parsing.py"], capture_output=True, text=True
    )

    try:
        return json.loads(result.stdout)
    except:
        return {
            "error_type": "execution_error",
            "raw_output": result.stdout,
            "stderr": result.stderr,
        }


# -----------------------------
# FILE IO
# -----------------------------


def save_code(code):
    with open("kv_store.py", "w") as f:
        f.write(code)


def load_code():
    if not os.path.exists("kv_store.py"):
        return ""
    with open("kv_store.py") as f:
        return f.read()


# -----------------------------
# LOGGING
# -----------------------------


def log_iteration(logs, iteration, code, result):
    logs.append({"iteration": iteration, "code": code, "result": result})


def save_logs(logs):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    with open(f"run_{ts}.json", "w") as f:
        json.dump(logs, f, indent=2)


# -----------------------------
# AGENT LOOP
# -----------------------------


def run_experiment():
    logs = []

    # Initial generation
    init_prompt = INIT_PROMPT_WITH_SPEC if USE_SPEC else INIT_PROMPT_NO_SPEC

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": init_prompt},
    ]

    code = call_llm(messages)
    save_code(code)

    for i in range(MAX_ITERS):
        print(f"\n=== ITERATION {i} ===")

        result = run_trace()
        log_iteration(logs, i, code, result)

        print(json.dumps(result, indent=2))

        # SUCCESS
        if result.get("status") == "success":
            print("\n🎉 SUCCESS")
            save_logs(logs)
            return

        # Build feedback
        feedback = json.dumps(result, indent=2)

        # Next iteration prompt
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": ITER_PROMPT_TEMPLATE.format(feedback=feedback, code=code),
            },
        ]

        code = call_llm(messages)
        save_code(code)

    print("\n❌ FAILED after max iterations")
    save_logs(logs)


# -----------------------------
# MAIN
# -----------------------------

if __name__ == "__main__":
    run_experiment()
