import json
from pprint import pprint
from dataclasses import dataclass

file = open("/Users/lanza/Dummy/ximple/build/.cmake/api/v1/reply/codemodel-v2-0a1d77333f3f3e852d8e.json", 'r')
j = json.load(file)

configurations = j["configurations"]
first_config = configurations[0]
targets_dict = first_config["targets"]

@dataclass
class Target:
    name: str
    artifacts: [str]
    sources: [str]
    type: str

targets: [Target] = []


def get_targets(codemodel):
    for target in targets_dict:
        name = None
        artifacts = []
        sources = []
        type = None

        directoryIndex = target["directoryIndex"]
        id = target["id"]
        jsonFile = target["jsonFile"]
        name = target["name"]
        projectIndex = target["projectIndex"]
        file = open(f"/Users/lanza/Dummy/ximple/build/.cmake/api/v1/reply/{jsonFile}", 'r')
        target_json = json.load(file)

        artifacts_dict = target_json["artifacts"]
        for artifact in artifacts_dict:
            path = artifact["path"]
            artifacts.append(path)
        sources_dict = target_json["sources"]
        for source in sources_dict:
            path = source["path"]
            sources.append(path)

        type = target_json["type"]

        targets.append(Target(name, artifacts, sources, type))

    return targets

