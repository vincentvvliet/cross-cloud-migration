# cross-cloud-migration

## Running the system
Running the system works as follows:
- Update `config/config.yaml`:
    - composition: Name of combined system
    - systems: the two systems that make up the composition (including guarantees)
- Run `scripts/run.sh`

#### Example config.yaml
```
composition:
  name: KVQueue
systems:
  queue:
    type: BaseQueue
    delivery: exactly_once
    max_size: 10

  kv:
    type: BaseKV
    consistency: strong
    conditional_writes: true
    idempotent_writes: true
    max_size: 10
```

## Testing singular system
To test singular system, call `quint run {system}.qnt --invariants {invariants}`. For Apalache Model checking, run `quint verify {system}.qnt --invariants {invariants}`.

## New system workflow
- Create quint file containing system and base invariants in `quint/systems/{system_type}/`
- Add system in `config/systems.json`:
    - import (str): import path
    - state (array): the state variables of the system. E.G `["queue", "inflight", "history"]`
    - actions (object): the actions of the system. Actions are defined as follows:
        `
        {
            arity (int): number of inputs,
            composite (bool): whether a composite version of an action needs to be made. This is dependant on whether all system variables are used or not in the original function.
            input (str): name of input
        }
        ` 
            
        E.G `"deliver": { "arity": 1, "composite": true, "input": "getHead(queue)"}`
    - init (str): name of `init` function in system 
- Define capabilities in `generator/capabilities.py`
- State system capabilities in `config/config.yaml`

## New composite system
- Create composite file with naming format: `{system_1}{system_2}.qnt`. E.G. `KVQueue, DynamoDBSQS, CassandraKafka`
- Add composite system to `config/systems.json`
- Create property dependant invariants in `generator/invariants.py`
    
After these steps, `scripts/run.sh` or `python generator/main.py` should generate the necessary composite quint files.