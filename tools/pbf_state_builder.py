#!/usr/bin/env python3
import argparse, json, math, os, re, sqlite3, sys, time
import osmium

CHUNK_SIZE = 250.0
ROAD_W = {
    "motorway": 14.0, "trunk": 13.0, "primary": 11.0,
    "secondary": 9.5, "tertiary": 8.5, "residential": 6.5,
    "unclassified": 6.0, "service": 4.5
}

PRESETS = {
    "miami-dade": {
        "name": "Miami-Dade County, FL", "biome": "florida_coast",
        "bbox": (25.13, -80.88, 25.98, -80.11), "origin": (25.7617, -80.1918)
    },
    "everglades": {
        "name": "Everglades, FL", "biome": "everglades",
        "bbox": (25.15, -81.15, 26.00, -80.45), "origin": (25.7570, -80.7650)
    },
    "south-fl": {
        "name": "South Florida", "biome": "florida_coast",
        "bbox": (24.50, -81.85, 26.95, -79.95), "origin": (25.7617, -80.1918)
    },
    "florida": {
        "name": "Florida (Statewide)", "biome": "florida_coast",
        "bbox": (24.35, -87.65, 31.05, -79.95), "origin": (28.5383, -81.3792)
    }
}

def parse_h(tags, wid: int) -> float:
    for k, mult in (("height", 1.0), ("building:levels", 3.5)):
        v = tags.get(k)
        if v:
            m = re.search(r"[\d.]+", v)
            if m:
                val = float(m.group(0)) * mult
                if k == "height" and "ft" in v.lower(): val *= 0.3048
                return max(3.5, min(val, 280.0))
    return 7.0 + (wid % 7) * 3.2

class FloridaCompiler(osmium.SimpleHandler):
    def __init__(self, conn, bbox, origin):
        super().__init__()
        self.conn = conn
        self.s, self.w, self.n, self.e = bbox
        self.olat, self.olon = origin
        self.cos_lat = math.cos(math.radians(self.olat))
        self.batch = []
        self.counts = {"b": 0, "r": 0, "w": 0}

    def _flush(self):
        if self.batch:
            self.conn.executemany("INSERT INTO feat VALUES (?,?,?,?)", self.batch)
            self.conn.commit()
            self.batch.clear()

    def _to_local(self, lat: float, lon: float):
        return (
            round((lon - self.olon) * 111320.0 * self.cos_lat, 2),
            round(-(lat - self.olat) * 111320.0, 2)
        )

    def way(self, w):
        tags = w.tags
        is_bldg = "building" in tags
        hw = tags.get("highway")
        is_road = hw in ROAD_W
        nat = tags.get("natural")
        is_water = (nat in ("water", "wetland")) or (tags.get("waterway") == "riverbank")
        if not (is_bldg or is_road or is_water):
            return

        # Fast bounding-box check on first valid node before full projection
        pts = []
        checked = False
        for nd in w.nodes:
            if not nd.location.valid():
                continue
            la, lo = nd.location.lat, nd.location.lon
            if not checked:
                if not (self.s <= la <= self.n and self.w <= lo <= self.e):
                    return
                checked = True
            pts.append(self._to_local(la, lo))

        if len(pts) < 2:
            return

        if is_bldg and len(pts) >= 4:
            if pts[0] == pts[-1]: pts = pts[:-1]
            if len(pts) < 3: return
            cx = math.floor((sum(p[0] for p in pts) / len(pts)) / CHUNK_SIZE)
            cz = math.floor((sum(p[1] for p in pts) / len(pts)) / CHUNK_SIZE)
            self.batch.append((cx, cz, "b", json.dumps({"pts": pts, "h": round(parse_h(tags, w.id), 2)}, separators=(",", ":"))))
            self.counts["b"] += 1
        elif is_road:
            width = ROAD_W[hw]
            for i in range(len(pts) - 1):
                p0, p1 = pts[i], pts[i + 1]
                cx = math.floor(((p0[0] + p1[0]) * 0.5) / CHUNK_SIZE)
                cz = math.floor(((p0[1] + p1[1]) * 0.5) / CHUNK_SIZE)
                self.batch.append((cx, cz, "r", json.dumps({"a": p0, "b": p1, "w": width}, separators=(",", ":"))))
            self.counts["r"] += 1
        elif is_water and len(pts) >= 4:
            if pts[0] == pts[-1]: pts = pts[:-1]
            if len(pts) < 3: return
            cx = math.floor((sum(p[0] for p in pts) / len(pts)) / CHUNK_SIZE)
            cz = math.floor((sum(p[1] for p in pts) / len(pts)) / CHUNK_SIZE)
            kind = "m" if nat == "wetland" else "w"
            self.batch.append((cx, cz, kind, json.dumps(pts, separators=(",", ":"))))
            self.counts["w"] += 1

        if len(self.batch) >= 40000:
            self._flush()
            print(f"  Indexed {self.counts['b']} bldgs, {self.counts['r']} roads, {self.counts['w']} water...", end="\r")

def main():
    ap = argparse.ArgumentParser(description="Compile florida-latest.osm.pbf into 250m Godot chunks")
    ap.add_argument("pbf", help="Path to florida-latest.osm.pbf")
    ap.add_argument("--preset", choices=PRESETS.keys(), default="miami-dade")
    ap.add_argument("--low-ram", action="store_true", help="Use disk-backed node cache instead of RAM")
    args = ap.parse_args()

    cfg = PRESETS[args.preset]
    slug = args.preset.replace("-", "_") + "_pbf"
    out_dir = os.path.join("world_data", slug)
    os.makedirs(out_dir, exist_ok=True)
    db_path = f"/tmp/{slug}_staging.db"
    if os.path.exists(db_path): os.remove(db_path)

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA synchronous=OFF")
    conn.execute("PRAGMA journal_mode=OFF")
    conn.execute("CREATE TABLE feat (cx INTEGER, cz INTEGER, kind TEXT, data TEXT)")

    t0 = time.time()
    idx = f"sparse_file_array,/tmp/{slug}_nodes.cache" if args.low_ram else "flex_mem"
    print(f"Scanning {args.pbf} for {cfg['name']} (idx={idx})...")
    handler = FloridaCompiler(conn, cfg["bbox"], cfg["origin"])
    handler.apply_file(args.pbf, locations=True, idx=idx)
    handler._flush()
    print(f"\nPass 1 done in {time.time() - t0:.1f}s: {handler.counts['b']} buildings, {handler.counts['r']} roads, {handler.counts['w']} water/marsh.")

    print("Sorting features by chunk & writing 250m JSON files...")
    conn.execute("CREATE INDEX idx_chunk ON feat (cx, cz)")
    cur = conn.execute("SELECT cx, cz, kind, data FROM feat ORDER BY cx, cz")

    chunk_keys = []
    cur_key = None
    buf = None
    kind_map = {"b": "buildings", "r": "roads", "w": "water", "m": "wetlands"}

    def write_chunk(k, data_dict):
        with open(os.path.join(out_dir, f"chunk_{k}.json"), "w") as f:
            json.dump(data_dict, f, separators=(",", ":"))
        chunk_keys.append(k)

    for cx, cz, kind, payload in cur:
        k = f"{cx}_{cz}"
        if k != cur_key:
            if buf is not None:
                write_chunk(cur_key, buf)
            cur_key = k
            buf = {"cx": cx, "cz": cz, "buildings": [], "roads": [], "water": [], "wetlands": []}
        buf[kind_map[kind]].append(json.loads(payload))
    if buf is not None:
        write_chunk(cur_key, buf)

    conn.close()
    os.remove(db_path)
    if args.low_ram and os.path.exists(f"/tmp/{slug}_nodes.cache"):
        os.remove(f"/tmp/{slug}_nodes.cache")

    manifest = {
        "slug": slug, "name": cfg["name"], "display_name": cfg["name"], "biome": cfg["biome"],
        "origin_lat": cfg["origin"][0], "origin_lon": cfg["origin"][1],
        "chunk_size": CHUNK_SIZE, "chunk_keys": chunk_keys
    }
    with open(os.path.join(out_dir, "manifest.json"), "w") as f: json.dump(manifest, f)
    with open(os.path.join("world_data", "active_city.json"), "w") as f: json.dump(manifest, f)

    reg_path = os.path.join("world_data", "regions.json")
    regs = json.load(open(reg_path)) if os.path.exists(reg_path) else []
    regs = [r for r in regs if r.get("slug") != slug]
    regs.append({"slug": slug, "name": cfg["name"], "biome": cfg["biome"]})
    with open(reg_path, "w") as f: json.dump(regs, f, indent=2)

    print(f"COMPLETE in {time.time() - t0:.1f}s! Wrote {len(chunk_keys)} chunks -> {out_dir}")

if __name__ == "__main__":
    main()
