#!/usr/bin/env bash
set -e
IMG="$1"
TARGET="${2:-player}" # "player", "npc_0", "npc_1", "npc_2", or a landmark name
if [ -z "$IMG" ]; then
  echo "Usage: ./tools/gen_3d_scan.sh /path/to/photo.png [player|npc_0|npc_1|npc_2]"
  exit 1
fi
source ~/TripoSR/.venv/bin/activate
OUT_TMP="/tmp/triposr_out"
rm -rf "$OUT_TMP"
python3 ~/TripoSR/run.py "$IMG" --device cpu --model-save-format glb --bake-texture --output-dir "$OUT_TMP"

if [ "$TARGET" = "player" ]; then
  DEST="$HOME/solis_coast_v2/assets/avatars/player.glb"
elif [[ "$TARGET" == npc_* ]]; then
  DEST="$HOME/solis_coast_v2/assets/avatars/npcs/${TARGET}.glb"
else
  DEST="$HOME/solis_coast_v2/assets/landmarks/${TARGET}.glb"
fi
cp "$OUT_TMP/0/mesh.glb" "$DEST"
echo "Dropped 3D scan into: $DEST"
