"""PROFILE MANAGER - Theme Profile Management"""
import json, shutil
from pathlib import Path
from .constants import THEMES_DIR, BUILTIN_DIR, CUSTOM_DIR, PROFILES_FILE, PREFERENCES_DIR, PREFERENCES_THEME_FILE, DEFAULT_WAYBAR_CONFIG
from .themes_data import BUILTIN_THEMES

class ThemeProfileManager:
    def __init__(self):
        for d in [THEMES_DIR, BUILTIN_DIR, CUSTOM_DIR, PREFERENCES_DIR]: d.mkdir(parents=True, exist_ok=True)
        self._init_builtin()
        self.profiles = self._load()
    
    def _init_builtin(self):
        for tid, td in BUILTIN_THEMES.items():
            tf = BUILTIN_DIR / f"{tid}.json"
            if not tf.exists():
                tf.write_text(json.dumps({"id": tid, "is_builtin": True, **td, "waybar": DEFAULT_WAYBAR_CONFIG.copy()}, indent=2))
    
    def _load(self):
        for f in [PREFERENCES_THEME_FILE, PROFILES_FILE]:
            try:
                if f.exists():
                    d = json.loads(f.read_text())
                    if d.get("active_profile"): return {"active_profile": d["active_profile"], "active_profile_type": d.get("active_profile_type", "builtin")}
            except: pass
        return {"active_profile": "one-dark", "active_profile_type": "builtin"}
    
    def save_profiles(self): PROFILES_FILE.write_text(json.dumps(self.profiles, indent=2))
    
    def get_active_theme(self):
        pid, ptype = self.profiles.get("active_profile", "one-dark"), self.profiles.get("active_profile_type", "builtin")
        tf = (BUILTIN_DIR if ptype == "builtin" else CUSTOM_DIR) / f"{pid}.json"
        if tf.exists(): return json.loads(tf.read_text())
        if pid in BUILTIN_THEMES: return {"id": pid, "is_builtin": True, **BUILTIN_THEMES[pid]}
        return {"id": "one-dark", "is_builtin": True, **BUILTIN_THEMES["one-dark"]}
    
    def set_active_theme(self, tid, is_builtin=True):
        self.profiles = {"active_profile": tid, "active_profile_type": "builtin" if is_builtin else "custom"}
        self.save_profiles()
    
    def get_all_themes(self):
        themes = [{"id": tid, "name": td["name"], "is_builtin": True} for tid, td in BUILTIN_THEMES.items()]
        for tf in CUSTOM_DIR.glob("*.json"):
            try:
                d = json.loads(tf.read_text())
                themes.append({"id": d.get("id", tf.stem), "name": d.get("name", tf.stem), "is_builtin": False})
            except: pass
        return themes
    
    def create_custom_theme(self, name, base_id=None):
        tid = ''.join(c for c in name.lower().replace(" ", "-") if c.isalnum() or c == '-')
        n = 1
        while (CUSTOM_DIR / f"{tid}.json").exists(): tid = f"{tid}-{n}"; n += 1
        base = BUILTIN_THEMES.get(base_id, BUILTIN_THEMES["one-dark"]).copy()
        base["name"] = name
        (CUSTOM_DIR / f"{tid}.json").write_text(json.dumps({"id": tid, "is_builtin": False, **base, "waybar": DEFAULT_WAYBAR_CONFIG.copy()}, indent=2))
        return tid
    
    def update_custom_theme(self, tid, updates):
        tf = CUSTOM_DIR / f"{tid}.json"
        if not tf.exists(): return False
        d = json.loads(tf.read_text())
        for k, v in updates.items():
            if isinstance(v, dict) and k in d and isinstance(d[k], dict): d[k].update(v)
            else: d[k] = v
        tf.write_text(json.dumps(d, indent=2))
        return True
    
    def delete_custom_theme(self, tid):
        tf = CUSTOM_DIR / f"{tid}.json"
        if tf.exists():
            tf.unlink()
            if self.profiles.get("active_profile") == tid: self.set_active_theme("one-dark", True)
            return True
        return False
    
    def export_theme(self, tid, path):
        for d in [BUILTIN_DIR, CUSTOM_DIR]:
            tf = d / f"{tid}.json"
            if tf.exists(): shutil.copy(tf, path); return True
        return False
    
    def import_theme(self, path):
        try:
            d = json.loads(Path(path).read_text())
            if "colors" not in d: return None
            tid = self.create_custom_theme(d.get("name", Path(path).stem))
            self.update_custom_theme(tid, {k: d[k] for k in ["colors", "rofi", "kitty"] if k in d})
            return tid
        except: return None
