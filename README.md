# cross-cloud-migration

## Running the system
Running the system works as follows:
- Update `config/config.yaml`:
    - composition: Name of combined system (Currently only supports KVQueue)
    - systems: the two systems that make up the composition
- Run `scripts/run.sh`

## Scripts
- `scripts/run.sh`: run system in config.yaml on its own invariants
- `scripts/run.sh compat`: run target system in compat.yaml against the invariants of source in compat.yaml
- `scripts/redis-experiment.sh`: run redis experiment with default Quint parameters
- `scripts/redis-experiment.sh long`: run redis experiment with sample size `1000` steps

#### Example config.yaml
```
composition:
  name: KVQueue
systems:
  queue: BaseQueue
  kv: BaseKV
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
            arg_type (str): type of arguments, see `generator/function_signature.py`,
            composite (bool): whether a composite version of an action needs to be made. This is dependant on whether all system variables are used or not in the original function.
            input (str): name of input
        }
        ` 
            
        E.G `"deliver": { "arg_type": "msg, "composite": true, "input": "getHead(queue)"}`
    - init (str): name of `init` function in system 
- Define capabilities in `generator/capabilities.py`
- State system capabilities in `config/{system_type}/{system}.yaml`

## New composite system
- Create composite file with naming format: `{system_1}{system_2}.qnt`. E.G. `KVQueue`
- Add composite system to `config/systems.json`
- Create property dependant invariants in `generator/invariants.py`
    
After these steps, `scripts/run.sh` or `python generator/main.py` should generate the necessary composite quint files.
