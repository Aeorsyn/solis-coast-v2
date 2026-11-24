#!/usr/bin/env python3
import json, math, os, re, sys, urllib.parse, urllib.request

UA = "SolisCoastEarthSim/1.1 (https://github.com/aeorsyn/solis-coast)"
NOMINATIM = "https://nominatim.openstreetmap.org/search"
OVERPASS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter"
]
CHUNK_SIZE = 250.0
ROAD_W = {
    "motorway": 14.0, "trunk": 13.0, "primary": 11.0,
    "secondary": 9.5, "tertiary": 8.5, "residential": 6.5,
    "unclassified": 6.0, "service": 4.5
}

def get_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode("utf-8"))

def geocode(q: str):
    p = urllib.parse.urlencode({"q": q, "format": "json", "limit": 1, "countrycodes": "us"})
    d = get_json(f"{NOMINATIM}?{p}")
    if not d: raise RuntimeError(f"Location not found: {q}")
    return float(d[0]["lat"]), float(d[0]["lon"]), d[0].get("display_name", q)

def fetch_osm(lat: float, lon: float, rad: float):
    dlat = rad / 111320.0
    dlon = rad / (111320.0 * math.cos(math.radians(lat)))
    s, n, w, e = lat - dlat, lat + dlat, lon - dlon, lon + dlon
    ql = f"""
    [out:json][timeout:75];
    (
      way["building"]({s},{w},{n},{e});
      way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified)$"]({s},{w},{n},{e});
      way["natural"~"^(water|wetland)$"]({s},{w},{n},{e});
      way["waterway"="riverbank"]({s},{w},{n},{e});
    );
    (._;>;);
    out body;
    """
    payload = urllib.parse.urlencode({"data": ql}).encode("utf-8")
    for ep in OVERPASS:
        try:
            print(f"Querying {ep} (radius={int(rad)}m)...")
            req = urllib.request.Request(ep, data=payload, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as ex:
            print(f"  Fallback triggered: {ex}")
    raise RuntimeError("All Overpass endpoints failed.")

def parse_h(tags: dict, wid: int) -> float:
    for k, mult in [("height", 1.0), ("building:levels", 3.5)]:
        v = tags.get(k)
        if v:
            m = re.search(r"[\d.]+", str(v))
            if m:
                val = float(m.group(0)) * mult
                if k == "height" and "ft" in str(v).lower(): val *= 0.3048
                return max(3.5, min(val, 280.0))
    return 7.0 + (wid % 7) * 3.2

def main():
    if len(sys.argv) < 2:
        print('Usage: python3 tools/osm_city_builder.py "City, ST" [radius_m] [biome]')
        print('Biomes: urban | florida_coast | everglades')
        sys.exit(1)

    q = sys.argv[1]
    rad = float(sys.argv[2]) if len(sys.argv) > 2 else 1000.0
    biome = sys.argv[3] if len(sys.argv) > 3 else ("everglades" if "everglades" in q.lower() else ("florida_coast" if ", fl" in q.lower() else "urban"))
    slug = re.sub(r"[^a-z0-9]+", "_", q.lower()).strip("_")

    lat, lon, disp = geocode(q)
    print(f"Geocoded: {disp} ({lat:.5f}, {lon:.5f}) | biome={biome}")
    osm = fetch_osm(lat, lon, rad)

    nodes = {el["id"]: (el["lat"], el["lon"]) for el in osm.get("elements", []) if el.get("type") == "node"}
    cos_lat = math.cos(math.radians(lat))
    to_local = lambda la, lo: (round((lo - lon) * 111320.0 * cos_lat, 2), round(-(la - lat) * 111320.0, 2))

    chunks = {}
    def gc(cx, cz):
        k = f"{cx}_{cz}"
        if k not in chunks:
            chunks[k] = {"cx": cx, "cz": cz, "buildings": [], "roads": [], "water": [], "wetlands": []}
        return chunks[k]

    bc = rc = wc = 0
    for el in osm.get("elements", []):
        if el.get("type") != "way": continue
        tags = el.get("tags", {})
        pts = [to_local(*nodes[i]) for i in el.get("nodes", []) if i in nodes]
        if len(pts) < 2: continue

        if "building" in tags and len(pts) >= 4:
            if pts[0] == pts[-1]: pts = pts[:-1]
            if len(pts) < 3: continue
            cx = math.floor((sum(p[0] for p in pts) / len(pts)) / CHUNK_SIZE)
            cz = math.floor((sum(p[1] for p in pts) / len(pts)) / CHUNK_SIZE)
            gc(cx, cz)["buildings"].append({"pts": pts, "h": round(parse_h(tags, el["id"]), 2)})
            bc += 1
        elif "highway" in tags:
            w = ROAD_W.get(tags["highway"], 6.5)
            for i in range(len(pts) - 1):
                p0, p1 = pts[i], pts[i + 1]
                cx = math.floor(((p0[0] + p1[0]) * 0.5) / CHUNK_SIZE)
                cz = math.floor(((p0[1] + p1[1]) * 0.5) / CHUNK_SIZE)
                gc(cx, cz)["roads"].append({"a": p0, "b": p1, "w": w})
            rc += 1
        elif (tags.get("natural") in ("water", "wetland") or tags.get("waterway") == "riverbank") and len(pts) >= 4:
            if pts[0] == pts[-1]: pts = pts[:-1]
            if len(pts) < 3: continue
            cx = math.floor((sum(p[0] for p in pts) / len(pts)) / CHUNK_SIZE)
            cz = math.floor((sum(p[1] for p in pts) / len(pts)) / CHUNK_SIZE)
            bucket = "wetlands" if tags.get("natural") == "wetland" else "water"
            gc(cx, cz)[bucket].append(pts)
            wc += 1

    out_dir = os.path.join("world_data", slug)
    os.makedirs(out_dir, exist_ok=True)
    for k, c in chunks.items():
        with open(os.path.join(out_dir, f"chunk_{k}.json"), "w") as f:
            json.dump(c, f, separators=(",", ":"))

    manifest = {
        "slug": slug, "name": q, "display_name": disp, "biome": biome,
        "origin_lat": lat, "origin_lon": lon, "chunk_size": CHUNK_SIZE,
        "chunk_keys": sorted(chunks.keys())
    }
    with open(os.path.join(out_dir, "manifest.json"), "w") as f: json.dump(manifest, f, indent=2)
    with open(os.path.join("world_data", "active_city.json"), "w") as f: json.dump(manifest, f, indent=2)

    reg_path = os.path.join("world_data", "regions.json")
    regs = json.load(open(reg_path)) if os.path.exists(reg_path) else []
    regs = [r for r in regs if r.get("slug") != slug]
    regs.append({"slug": slug, "name": q, "biome": biome})
    with open(reg_path, "w") as f: json.dump(regs, f, indent=2)
    print(f"DONE! {q} [{biome}]: {bc} buildings, {rc} roads, {wc} water/wetlands across {len(chunks)} chunks.")

if __name__ == "__main__":
    main()
