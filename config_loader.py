import os
import yaml
from typing import Any, Dict, Optional, List


class ConfigDocument:
    """
    Generic wrapper for capability documents (QueueCapabilities, DynamoDBCapabilities, etc).
    Provides dot-attribute access and preserves nested structure.
    """

    def __init__(self, name: str, raw: Dict[str, Any], kind: str):
        self.name = name               # e.g., "QueueCapabilities", "DynamoDBCapabilities"
        self.kind = kind               # "queue" or "kv"
        self.raw = raw                 # internal content dict

    def __getattr__(self, item: str) -> Any:
        if item in self.raw:
            return self.raw[item]
        raise AttributeError(f"{self.name} has no attribute '{item}'")

    def __repr__(self):
        return f"ConfigDocument(name={self.name}, kind={self.kind}, keys={list(self.raw.keys())})"


class ConfigLoader:
    """
    Unified loader for QueueCapabilities and KVStoreCapabilities.
    Directory structure:
      /queue/config/*.yaml
      /key-value/config/*.yaml
    """

    def __init__(self,
                 kv_path: str = "./key-value/config",
                 queue_path: str = "./queue/config"):
        self.kv_path = kv_path
        self.queue_path = queue_path

        self.documents: Dict[str, ConfigDocument] = {}

    # ----------------------------------------------------------------------
    # MAIN ENTRYPOINTS
    # ----------------------------------------------------------------------

    def load_all(self) -> Dict[str, ConfigDocument]:
        self._load_dir(self.kv_path, kind="kv")
        self._load_dir(self.queue_path, kind="queue")
        return self.documents

    def get(self, name: str) -> Optional[ConfigDocument]:
        return self.documents.get(name)

    # ----------------------------------------------------------------------
    # INTERNAL HELPERS
    # ----------------------------------------------------------------------

    def _load_dir(self, folder: str, kind: str):
        if not os.path.exists(folder):
            return  # silently skip missing folders

        for filename in os.listdir(folder):
            if filename.endswith(".yaml") or filename.endswith(".yml"):
                self._load_single(os.path.join(folder, filename), kind)

    def _load_single(self, filepath: str, kind: str):
        with open(filepath, "r") as f:
            data = yaml.safe_load(f)

        if not isinstance(data, dict) or len(data) != 1:
            raise ValueError(
                f"Invalid capability document in {filepath}: "
                "top-level must contain exactly one root key."
            )

        name = next(iter(data))
        content = data[name]

        if not isinstance(content, dict):
            raise ValueError(f"{name} must map to an object (dict)")

        doc = ConfigDocument(name=name, raw=content, kind=kind)
        self.documents[name] = doc

    # ----------------------------------------------------------------------
    # OPTIONAL SCHEMA VALIDATION
    # ----------------------------------------------------------------------

    def validate(self,
                 doc: ConfigDocument,
                 schema: Dict[str, List[str]]):
        """
        Validates that sections + fields exist.
        schema example:
            {
              "delivery": ["type", "scopedTo"],
              "ordering": ["type"]
            }
        """

        for section, fields in schema.items():
            if section not in doc.raw:
                raise ValueError(f"{doc.name} missing required section '{section}'")

            section_obj = doc.raw[section]
            if not isinstance(section_obj, dict):
                raise ValueError(f"{doc.name}.{section} must be a mapping")

            for field in fields:
                if field not in section_obj:
                    raise ValueError(
                        f"{doc.name}.{section} missing required field '{field}'"
                    )

if __name__ == '__main__':
    loader = ConfigLoader()
    docs = loader.load_all()
    dynamo = loader.get("DynamoDBCapabilities")

    print(docs)
    print(dynamo.consistency)
    print(dynamo.durability["persistence"])
    print(dynamo.transactions["supportsTransactions"])
