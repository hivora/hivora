#!/usr/bin/env bash
# tools/sync_renderer.sh — sync upstream liquid_glass_renderer into lib/src/renderer/
#
# Usage:  ./tools/sync_renderer.sh <version>
# e.g.:   ./tools/sync_renderer.sh 0.2.0-dev.5
#
# What this does
# ──────────────
# 1. Validates the upstream version is in pub cache.
# 2. Auto-syncs 11 "clean" Dart files (import-path fixes only; no logic change).
# 3. Syncs the 6 shader files we use (2 .frag + 4 .glsl).
# 4. Stages 5 "structural" Dart files into .upstream_<version>/ for manual diff.
#    (These are the files where we removed FakeGlass / useFake code paths.)
# 5. Updates RENDERER_ATTRIBUTION.md.
# 6. Runs flutter analyze on the auto-synced result.
#
# After running, manually reconcile the 5 staged files (see instructions printed
# at the end), then delete the staging dir and run flutter test.

set -euo pipefail

# ─── Args ────────────────────────────────────────────────────────────────────

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./tools/sync_renderer.sh <version>"
  echo "  e.g. ./tools/sync_renderer.sh 0.2.0-dev.5"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUB_CACHE="${HOME}/.pub-cache/hosted/pub.dev/liquid_glass_renderer-${VERSION}"
UPSTREAM_SRC="${PUB_CACHE}/lib/src"
UPSTREAM_SHADERS="${PUB_CACHE}/lib/assets/shaders"
RENDERER_DST="${REPO_ROOT}/lib/src/renderer"
SHADERS_DST="${REPO_ROOT}/shaders"
STAGING_DIR="${RENDERER_DST}/.upstream_${VERSION}"
TODAY="$(date +%Y-%m-%d)"

# ─── 1. Validate pub cache ────────────────────────────────────────────────────

if [[ ! -d "$PUB_CACHE" ]]; then
  echo "✗  pub cache not found: $PUB_CACHE"
  echo ""
  echo "Fetch the package first:"
  echo ""
  echo "  flutter pub global activate liquid_glass_renderer $VERSION"
  echo ""
  echo "If that fails (dev release not globally activatable), use a temp project:"
  echo ""
  echo "  cd /tmp && flutter create _tmp && cd _tmp \\"
  echo "    && flutter pub add 'liquid_glass_renderer:$VERSION' \\"
  echo "    && cd /tmp && rm -rf _tmp"
  echo ""
  exit 1
fi

if [[ ! -d "$UPSTREAM_SRC" ]]; then
  echo "✗  Expected lib/src/ not found inside pub cache."
  echo "   Check the package structure at: $PUB_CACHE"
  exit 1
fi

if [[ ! -d "$UPSTREAM_SHADERS" ]]; then
  echo "⚠  Shader directory not found at: $UPSTREAM_SHADERS"
  echo "   Shader sync will be skipped. Check the upstream layout."
  SKIP_SHADERS=1
else
  SKIP_SHADERS=0
fi

echo "✓  Upstream: $PUB_CACHE"
echo "   Syncing to: $RENDERER_DST"
echo ""

# ─── Helper: copy + apply import-path fixes ───────────────────────────────────
#
# Transforms upstream package: imports to relative imports within lib/src/renderer/.
#
# depth = "root"      — file lives at lib/src/renderer/*.dart
# depth = "internal"  — file lives at lib/src/renderer/internal/*.dart
# depth = "rendering" — file lives at lib/src/renderer/rendering/*.dart
#
apply_import_fixes() {
  local src="$1"
  local dst="$2"
  local depth="$3"

  cp "$src" "$dst"

  case "$depth" in
    root)
      # package:liquid_glass_renderer/src/internal/X → internal/X
      sed -i '' "s|'package:liquid_glass_renderer/src/internal/|'internal/|g" "$dst"
      # package:liquid_glass_renderer/src/rendering/X → rendering/X
      sed -i '' "s|'package:liquid_glass_renderer/src/rendering/|'rendering/|g" "$dst"
      # package:liquid_glass_renderer/src/X → X  (same directory)
      sed -i '' "s|'package:liquid_glass_renderer/src/|'|g" "$dst"
      # barrel import
      sed -i '' "s|'package:liquid_glass_renderer/liquid_glass_renderer.dart'|'liquid_glass_renderer.dart'|g" "$dst"
      ;;
    internal)
      # same subdir
      sed -i '' "s|'package:liquid_glass_renderer/src/internal/|'|g" "$dst"
      # sibling subdir
      sed -i '' "s|'package:liquid_glass_renderer/src/rendering/|'../rendering/|g" "$dst"
      # root files → one level up
      sed -i '' "s|'package:liquid_glass_renderer/src/|'../|g" "$dst"
      # barrel import
      sed -i '' "s|'package:liquid_glass_renderer/liquid_glass_renderer.dart'|'../liquid_glass_renderer.dart'|g" "$dst"
      ;;
    rendering)
      # same subdir
      sed -i '' "s|'package:liquid_glass_renderer/src/rendering/|'|g" "$dst"
      # sibling subdir
      sed -i '' "s|'package:liquid_glass_renderer/src/internal/|'../internal/|g" "$dst"
      # root files → one level up
      sed -i '' "s|'package:liquid_glass_renderer/src/|'../|g" "$dst"
      # barrel import
      sed -i '' "s|'package:liquid_glass_renderer/liquid_glass_renderer.dart'|'../liquid_glass_renderer.dart'|g" "$dst"
      ;;
    *)
      echo "✗  Unknown depth: $depth"
      exit 1
      ;;
  esac
}

# ─── 2. Auto-sync clean Dart files ───────────────────────────────────────────
#
# These files contain only import-path differences from upstream.
# We apply the mechanical import transform and copy them directly.

echo "── Auto-syncing clean Dart files ──────────────────────────────────────────"

# Root-level clean files (upstream: lib/src/*.dart)
ROOT_CLEAN=(
  glass_glow.dart
  liquid_glass_settings.dart
  liquid_shape.dart
  logging.dart
  stretch.dart
)

for f in "${ROOT_CLEAN[@]}"; do
  src="${UPSTREAM_SRC}/${f}"
  dst="${RENDERER_DST}/${f}"
  if [[ ! -f "$src" ]]; then
    echo "  ⚠  Missing upstream: src/${f} — skipped"
    continue
  fi
  apply_import_fixes "$src" "$dst" root
  echo "  ✓  ${f}"
done

# Internal clean files (upstream: lib/src/internal/*.dart)
INTERNAL_CLEAN=(
  glass_drag_builder.dart
  multi_shader_builder.dart
  render_liquid_glass_geometry.dart
  snap_rect_to_pixels.dart
  transform_tracking_repaint_boundary_mixin.dart
)

for f in "${INTERNAL_CLEAN[@]}"; do
  src="${UPSTREAM_SRC}/internal/${f}"
  dst="${RENDERER_DST}/internal/${f}"
  if [[ ! -f "$src" ]]; then
    echo "  ⚠  Missing upstream: src/internal/${f} — skipped"
    continue
  fi
  apply_import_fixes "$src" "$dst" internal
  echo "  ✓  internal/${f}"
done

# Rendering clean files (upstream: lib/src/rendering/*.dart)
RENDERING_CLEAN=(
  liquid_glass_render_object.dart
)

for f in "${RENDERING_CLEAN[@]}"; do
  src="${UPSTREAM_SRC}/rendering/${f}"
  dst="${RENDERER_DST}/rendering/${f}"
  if [[ ! -f "$src" ]]; then
    echo "  ⚠  Missing upstream: src/rendering/${f} — skipped"
    continue
  fi
  apply_import_fixes "$src" "$dst" rendering
  echo "  ✓  rendering/${f}"
done

echo ""

# ─── 3. Sync shaders ─────────────────────────────────────────────────────────
#
# Only the shaders we actually use (registered in pubspec.yaml / ShaderKeys).
# Dead upstream shaders (liquid_glass_filter.frag, liquid_glass_arbitrary.frag)
# are intentionally excluded.

if [[ "$SKIP_SHADERS" -eq 0 ]]; then
  echo "── Syncing shaders ─────────────────────────────────────────────────────────"

  SYNC_SHADERS=(
    # .frag files (registered in pubspec.yaml shaders:)
    liquid_glass_geometry_blended.frag
    liquid_glass_final_render.frag
    # .glsl files (#include'd by the .frag files above)
    render.glsl
    shared.glsl
    sdf.glsl
    displacement_encoding.glsl
  )

  for f in "${SYNC_SHADERS[@]}"; do
    src="${UPSTREAM_SHADERS}/${f}"
    dst="${SHADERS_DST}/${f}"
    if [[ ! -f "$src" ]]; then
      echo "  ⚠  Missing upstream shader: ${f} — skipped"
      continue
    fi
    cp "$src" "$dst"
    echo "  ✓  shaders/${f}"
  done

  echo ""
fi

# ─── 4. Stage structural files ───────────────────────────────────────────────
#
# These files were structurally changed by us (FakeGlass / useFake removal).
# We stage the import-fixed upstream version for manual diff — do NOT auto-copy.

echo "── Staging structural files for manual review ──────────────────────────────"
echo "   (import fixes applied; FakeGlass/useFake changes intentionally retained)"
echo ""

mkdir -p "${STAGING_DIR}/rendering"

STRUCTURAL_ROOT=(
  liquid_glass.dart           # FakeGlass widget removed
  liquid_glass_render_scope.dart  # useFake param removed
  liquid_glass_blend_group.dart   # useFake param removed
  shaders.dart                # prefix + dead ShaderKeys entries
)

for f in "${STRUCTURAL_ROOT[@]}"; do
  src="${UPSTREAM_SRC}/${f}"
  staged="${STAGING_DIR}/${f}"
  if [[ ! -f "$src" ]]; then
    echo "  ⚠  Missing upstream: src/${f} — skipped"
    continue
  fi
  apply_import_fixes "$src" "$staged" root
  echo "  staged  .upstream_${VERSION}/${f}"
done

STRUCTURAL_RENDERING=(
  liquid_glass_layer.dart     # fake: param removed
)

for f in "${STRUCTURAL_RENDERING[@]}"; do
  src="${UPSTREAM_SRC}/rendering/${f}"
  staged="${STAGING_DIR}/rendering/${f}"
  if [[ ! -f "$src" ]]; then
    echo "  ⚠  Missing upstream: src/rendering/${f} — skipped"
    continue
  fi
  apply_import_fixes "$src" "$staged" rendering
  echo "  staged  .upstream_${VERSION}/rendering/${f}"
done

echo ""

# ─── 5. Manual reconciliation instructions ───────────────────────────────────

cat << INSTRUCTIONS
── Manual reconciliation ───────────────────────────────────────────────────────

For each staged file, diff upstream against our version and apply any
Impeller-path improvements from upstream. Ignore FakeGlass/useFake hunks —
we intentionally stripped those.

  diff lib/src/renderer/liquid_glass.dart \\
       lib/src/renderer/.upstream_${VERSION}/liquid_glass.dart

  diff lib/src/renderer/liquid_glass_render_scope.dart \\
       lib/src/renderer/.upstream_${VERSION}/liquid_glass_render_scope.dart

  diff lib/src/renderer/liquid_glass_blend_group.dart \\
       lib/src/renderer/.upstream_${VERSION}/liquid_glass_blend_group.dart

  diff lib/src/renderer/rendering/liquid_glass_layer.dart \\
       lib/src/renderer/.upstream_${VERSION}/rendering/liquid_glass_layer.dart

  diff lib/src/renderer/shaders.dart \\
       lib/src/renderer/.upstream_${VERSION}/shaders.dart

For shaders.dart specifically, the staged version will have upstream's package
prefix and all ShaderKeys entries. When merging, keep:
  • _shadersRoot prefix: 'packages/liquid_glass_widgets/' (NOT 'liquid_glass_renderer')
  • Only ShaderKeys.blendedGeometry and ShaderKeys.liquidGlassRender
  • The _kIsTest / Platform.environment override for test environments

After reconciliation:
  rm -rf lib/src/renderer/.upstream_${VERSION}/

────────────────────────────────────────────────────────────────────────────────

INSTRUCTIONS

# ─── 6. Update RENDERER_ATTRIBUTION.md ───────────────────────────────────────

echo "── Updating RENDERER_ATTRIBUTION.md ────────────────────────────────────────"
ATTRIBUTION="${RENDERER_DST}/RENDERER_ATTRIBUTION.md"
if [[ -f "$ATTRIBUTION" ]]; then
  sed -i '' "s|Vendored version: \*\*[^*]*\*\* (.*)|Vendored version: **${VERSION}** (synced ${TODAY})|" "$ATTRIBUTION"
  echo "  ✓  Version → ${VERSION}, date → ${TODAY}"
else
  echo "  ⚠  RENDERER_ATTRIBUTION.md not found — skipped"
fi
echo ""

# ─── 7. flutter analyze ──────────────────────────────────────────────────────

echo "── Running flutter analyze ─────────────────────────────────────────────────"
cd "$REPO_ROOT"
if flutter analyze --fatal-infos 2>&1 | tail -25; then
  echo ""
  echo "✓  Sync complete: liquid_glass_renderer ${VERSION}"
else
  echo ""
  echo "✗  flutter analyze reported issues — review before committing."
fi

echo ""
echo "Next steps:"
echo "  1. Reconcile the 5 structural files (see diff commands above)"
echo "  2. Apply Impeller-path improvements; skip FakeGlass/useFake hunks"
echo "  3. rm -rf lib/src/renderer/.upstream_${VERSION}/"
echo "  4. flutter test"
echo "  5. git add -A && git commit -m 'chore: sync renderer to ${VERSION}'"
