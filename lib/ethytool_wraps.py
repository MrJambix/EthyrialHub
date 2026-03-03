"""
╔══════════════════════════════════════════════════════════════════════╗
║                     EthyTool Wraps v1.0                              ║
║                                                                      ║
║  Simple global functions that wrap conn.whatever() calls.            ║
║  Import this in scripts for the easiest possible API.                ║
║                                                                      ║
║  USAGE IN SCRIPTS:                                                   ║
║    from ethytool_wraps import *                                      ║
║                                                                      ║
║  ─── PLAYER ───────────────────────────────────────────────────────  ║
║    hp()                → 85.5                                        ║
║    mp()                → 92.3                                        ║
║    max_hp()            → 4785                                        ║
║    max_mp()            → 1011                                        ║
║    gold()              → 54321                                       ║
║    pos()               → (4718.0, 1306.0, 1.0)                      ║
║    x() / y() / z()                                                   ║
║    speed()             → 4.5                                         ║
║    food()              → 85.0                                        ║
║    job()               → "Mining"                                    ║
║    alive()             → True                                        ║
║    moving()            → False                                       ║
║    frozen()            → False                                       ║
║    combat()            → True                                        ║
║    safe_zone()         → False                                       ║
║    wildlands()         → True                                        ║
║    low_hp(30)          → True if below 30%                           ║
║    low_mp(20)          → True if below 20%                           ║
║    dist(x, y)          → 42.5                                        ║
║    near(x, y, 10)      → True if within 10 units                    ║
║                                                                      ║
║  ─── TARGET ───────────────────────────────────────────────────────  ║
║    target()            → {"name":"Wolf", "hp":60, ...} or None       ║
║    target_hp()         → 60.5                                        ║
║    target_name()       → "Wolf"                                      ║
║    has_target()        → True                                        ║
║    target_dead()       → False                                       ║
║    target_boss()       → False                                       ║
║    target_elite()      → False                                       ║
║    friendly()          → {"name":"Healer", ...} or None              ║
║                                                                      ║
║  ─── CASTING ──────────────────────────────────────────────────────  ║
║    cast("Fireball")    → True if cast worked                         ║
║    cast_first(["A","B"]) → name of first that worked or None         ║
║    spells()            → [{"name":"Fireball", ...}]                  ║
║    spell_names()       → ["Fireball", "Heal"]                        ║
║    spell_set()         → {"fireball", "heal", ...}                   ║
║    has_spell("Heal")   → True                                        ║
║    spell_ready("Heal") → True if off cooldown                        ║
║    my_class()          → "Warrior"                                   ║
║    available(["A","B"])→ ["A"] (only spells you have)                ║
║                                                                      ║
║  ─── GATHERING ────────────────────────────────────────────────────  ║
║    use("Stone")        → True if interaction started                 ║
║    progress()          → True if bar active                          ║
║    wait_progress()     → blocks until bar finishes                   ║
║    gather("Stone")     → full cycle: use + wait + delay              ║
║    doodads()           → [{"class":"Doodad", "name":"Stone", ...}]   ║
║    harvestable()       → only full (non-hidden) nodes                ║
║    scan()              → all nearby entities (DLL scanner)           ║
║    scan_all()          → all scene entities (DLL scanner)            ║
║                                                                      ║
║  ─── NEARBY / SCENE ──────────────────────────────────────────────  ║
║    nearby()            → [{"name":"Wolf", ...}]                      ║
║    nearby_mobs()       → living entities with HP                     ║
║    nearby_names()      → ["Wolf", "Bear"]                            ║
║    nearby_count()      → 12                                          ║
║    find("Wolf")        → first nearby match or None                  ║
║    count("Wolf")       → 3                                           ║
║    scene()             → all scene entities                          ║
║    scene_count()       → 250                                         ║
║    corpses()           → scene corpses                               ║
║    find_scene("Chest") → first scene match or None                   ║
║    find_all_scene("Ore") → all scene matches                        ║
║    closest(name)       → closest nearby entity                       ║
║    closest_scene(name) → closest scene entity                        ║
║                                                                      ║
║  ─── INVENTORY ────────────────────────────────────────────────────  ║
║    items()             → [{"name":"Iron Ore", ...}]                  ║
║    item_count()        → 24                                          ║
║    item_names()        → ["Iron Ore", "Potion"]                      ║
║    has("Potion")       → True                                        ║
║    count_item("Ore")   → 47                                          ║
║    find_item("Sword")  → first match or None                         ║
║    equipped()          → [{"name":"Iron Sword", ...}]                ║
║                                                                      ║
║  ─── LOOT ─────────────────────────────────────────────────────────  ║
║    loot()              → True if looted                              ║
║    loot_nearest()      → find + open + loot                          ║
║    auto_loot()         → open + loot                                 ║
║    open_corpse()       → True if opened                              ║
║    list_corpses()      → [{"corpseOf":1234, ...}]                   ║
║    has_loot()          → True if loot window open                    ║
║    loot_items()        → items in loot window                        ║
║    last_corpse()       → last corpse info or None                    ║
║                                                                      ║
║  ─── CAMERA ───────────────────────────────────────────────────────  ║
║    camera()            → {"distance":12, "angle":180, ...}          ║
║    zoom()              → 12.0                                        ║
║    angle()             → 180.0                                       ║
║    pitch()             → 52.0                                        ║
║                                                                      ║
║  ─── WAIT ─────────────────────────────────────────────────────────  ║
║    heal_if_low("Heal", 50)                                           ║
║    wait_no_combat()    → blocks until out of combat                  ║
║    wait_hp(90)         → blocks until HP above 90%                   ║
║    wait_still()        → blocks until not moving                     ║
║    wait_dead()         → blocks until target dead                    ║
║    wait_spell("Heal")  → blocks until spell ready                   ║
║    sleep(1)            → time.sleep shortcut                         ║
║                                                                      ║
║  ─── BULK / SYSTEM ────────────────────────────────────────────────  ║
║    all_stats()         → {"hp":85, "gold":54321, ...}               ║
║    ping()              → True                                        ║
║    init()              → (True, "OK")                                ║
║    version()           → "3.0.0"                                     ║
╚══════════════════════════════════════════════════════════════════════╝
"""

import time as _time

# ══════════════════════════════════════════════════════════════
#  The 'conn' object is injected by the dashboard before this
#  module is used. Scripts do: from ethytool_wraps import *
# ══════════════════════════════════════════════════════════════

# ─── PLAYER ───

def hp():          return conn.get_hp()
def mp():          return conn.get_mp()
def max_hp():      return conn.get_max_hp()
def max_mp():      return conn.get_max_mp()
def gold():        return conn.get_gold()
def pos():         return conn.get_position()
def x():           return conn.get_x()
def y():           return conn.get_y()
def z():           return conn.get_z()
def speed():       return conn.get_speed()
def food():        return conn.get_food()
def job():         return conn.get_job()
def alive():       return conn.is_alive()
def moving():      return conn.is_moving()
def frozen():      return conn.is_frozen()
def combat():      return conn.in_combat()
def safe_zone():   return conn.in_safe_zone()
def wildlands():   return conn.in_wildlands()
def low_hp(t=30):  return conn.is_low_hp(t)
def low_mp(t=20):  return conn.is_low_mp(t)
def dist(x, y):    return conn.distance_to(x, y)
def near(x, y, r=5): return conn.is_near(x, y, r)

# ─── TARGET ───

def target():       return conn.get_target()
def target_hp():    return conn.get_target_hp()
def target_name():  return conn.get_target_name()
def has_target():   return conn.has_target()
def target_dead():  return conn.is_target_dead()
def target_boss():  return conn.is_target_boss()
def target_elite(): return conn.is_target_elite()
def friendly():     return conn.get_friendly_target()

# ─── CASTING ───

def cast(name):           return conn.cast(name)
def cast_first(lst):      return conn.cast_first(lst)
def spells():             return conn.get_spells()
def spell_names():        return conn.get_spell_names()
def spell_set():          return conn.get_spell_set()
def has_spell(name):      return conn.has_spell(name)
def spell_ready(name):    return conn.is_spell_ready(name)
def my_class():           return conn.detect_class()
def available(lst):       return conn.filter_available(lst)

# ─── GATHERING ───

def use(name):            return conn.use_entity(name)
def progress():           return conn.has_progress()
def wait_progress(t=30):  return conn.wait_progress(t)
def gather(name, d=3):    return conn.gather(name, d)
def doodads():            return conn.scan_doodads()
def harvestable(skip=None): return conn.scan_harvestable(skip)
def scan():               return conn.scan_nearby()
def scan_all():           return conn.scan_scene()

# ─── NEARBY / SCENE ───

def nearby():             return conn.get_nearby()
def nearby_mobs():        return conn.get_nearby_mobs()
def nearby_names():       return conn.get_nearby_names()
def nearby_count():       return conn.get_nearby_count()
def find(name):           return conn.find_nearby(name)
def count(name=None):     return conn.count_nearby(name)
def scene():              return conn.get_scene()
def scene_count():        return conn.get_scene_count()
def corpses():            return conn.get_scene_corpses()
def find_scene(name):     return conn.find_in_scene(name)
def find_all_scene(name): return conn.find_all_in_scene(name)
def closest(name=None):   return conn.find_closest_nearby(name)
def closest_scene(name=None): return conn.find_closest_in_scene(name)

# ─── INVENTORY ───

def items():              return conn.get_inventory()
def item_count():         return conn.get_inv_count()
def item_names():         return conn.get_item_names()
def has(name):            return conn.has_item(name)
def count_item(name):     return conn.count_item(name)
def find_item(name):      return conn.find_item(name)
def equipped():           return conn.get_equipped()

# ─── LOOT ───

def loot():               return conn.loot()
def loot_nearest():       return conn.loot_nearest()
def auto_loot():          return conn.auto_loot()
def open_corpse():        return conn.open_corpse()
def list_corpses():       return conn.list_corpses()
def has_loot():           return conn.has_loot_window()
def loot_items():         return conn.get_loot_window_items()
def last_corpse():        return conn.get_last_corpse()

# ─── CAMERA ───

def camera():             return conn.get_camera()
def zoom():               return conn.get_camera_distance()
def angle():              return conn.get_camera_angle()
def pitch():              return conn.get_camera_pitch()

# ─── WAIT ───

def heal_if_low(name="Heal", t=50): return conn.heal_if_low(name, t)
def wait_no_combat(t=60):  return conn.wait_until_out_of_combat(t)
def wait_hp(t=90):         return conn.wait_until_hp_above(t)
def wait_still(t=30):      return conn.wait_until_not_moving(t)
def wait_dead(t=120):      return conn.wait_until_target_dead(t)
def wait_spell(name, t=30): return conn.wait_for_spell_ready(name, t)
def sleep(s):              _time.sleep(s)

# ─── BULK / SYSTEM ───

def all_stats():           return conn.get_all()
def ping():                return conn.ping()
def init():                return conn.init()
def version():             return conn.get_version()