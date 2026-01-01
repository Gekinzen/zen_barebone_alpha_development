import json
from pathlib import Path
from typing import List, Dict

PREFERENCES_DIR = Path.home() / ".config" / "hypr-control-center" / "preferences"
TASKBAR_FILE = PREFERENCES_DIR / "taskbar.json"


class TaskbarPreferences:
    def __init__(self):
        PREFERENCES_DIR.mkdir(parents=True, exist_ok=True)
        if not TASKBAR_FILE.exists():
            TASKBAR_FILE.write_text(json.dumps({"pinned": []}, indent=4))

    def load(self) -> Dict:
        try:
            return json.loads(TASKBAR_FILE.read_text())
        except Exception:
            return {"pinned": []}

    def save(self, data: Dict):
        TASKBAR_FILE.write_text(json.dumps(data, indent=4))

    def get_pinned(self) -> List[str]:
        return self.load().get("pinned", [])

    def is_pinned(self, app_id: str) -> bool:
        return app_id in self.get_pinned()

    def pin(self, app_id: str):
        data = self.load()
        if app_id not in data["pinned"]:
            data["pinned"].append(app_id)
            self.save(data)

    def unpin(self, app_id: str):
        data = self.load()
        if app_id in data["pinned"]:
            data["pinned"].remove(app_id)
            self.save(data)
