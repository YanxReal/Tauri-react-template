#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# patch-tauri-cli.sh — applies the 3 local tweaks onto a STOCK `tauri-cli`
# copy (documented in root `MODS.md`).
#
#   ./scripts/patch-tauri-cli.sh [VENDOR_DIR]
#     default: src-tauri/vendor/tauri-cli-2.12.0
#
# THE VERSION MATTERS: this script only knows the base declared in
# BASE_VERSION. If the vendor Cargo.toml says otherwise, the script refuses
# to run — review the blocks below against the new stock, update them, bump
# BASE_VERSION (plus MODS.md). That is the rebase flow; details in MODS.md
# "Rebase checklist".
#
# Each block is idempotent: already applied → skip; neither result nor stock
# context found → fail loudly instead of half-patching.
# ---------------------------------------------------------------------------
set -euo pipefail

BASE_VERSION="2.12.0"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: ./scripts/patch-tauri-cli.sh [VENDOR_DIR]"
  echo "Applies the 3 local tweaks onto a stock tauri-cli copy."
  echo "Defaults to src-tauri/vendor/tauri-cli-<BASE_VERSION> (see BASE_VERSION below)."
  exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="${1:-$ROOT/src-tauri/vendor/tauri-cli-2.12.0}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -d "$VENDOR/src/mobile" ]] || die "no stock copy at $VENDOR"

# --- version pin -------------------------------------------------------------
VER="$(grep -m1 '^version = ' "$VENDOR/Cargo.toml" | cut -d'"' -f2)"
[[ "$VER" == "$BASE_VERSION" ]] || die \
  "this script is current for tauri-cli $BASE_VERSION but the vendor says $VER.
   Review the 3 blocks below against the new stock, update them, bump
   BASE_VERSION and update MODS.md (see its 'Rebase checklist')."

export VENDOR
log "patching $VENDOR (base $BASE_VERSION)"

python3 - <<'PY'
import os, pathlib, sys

v = pathlib.Path(os.environ["VENDOR"])
failures = []

def check(name, cond, hint):
    print(("  OK " if cond else "  FALLO ") + name)
    if not cond:
        failures.append(f"{name}: {hint}")

# --- MOD-1a: fallback_options() antes de fetch_options -----------------------
mod_rs = v / "src/mobile/mod.rs"
s = mod_rs.read_text()
if "fn fallback_options" in s:
    print("  SKIP MOD-1a (fallback_options ya existe)")
else:
    anchor = "/// Requests the CLI options from the `dev` or `build` command that started the IDE build.\nfn fetch_options(target: Target, tauri_dir: &Path) -> Result<CliOptions> {"
    block = '''/// CLI options for standalone IDE builds (no `tauri ios|android dev|build`
/// parent process). The behavior follows the Xcode `CONFIGURATION` variable
/// (set by the IDE in the script phase):
///
/// - `release`: production semantics — enable `tauri/custom-protocol` so the
///   tauri crate compiles with `cfg(dev) = false` and the app embeds
///   `frontendDist` instead of loading `build.devUrl` — without it, a Release
///   build from Xcode would try to reach the dev server on localhost.
/// - `debug` (or unset, e.g. Android Studio): dev semantics — empty features,
///   so `cfg(dev) = true` and the app loads `build.devUrl` (the dev server
///   with hot reload, started by the IDE build phase when needed).
fn fallback_options() -> CliOptions {
  let release = std::env::var("CONFIGURATION")
    .map(|c| c.eq_ignore_ascii_case("release"))
    .unwrap_or(false);
  CliOptions {
    dev: !release,
    features: if release {
      vec!["tauri/custom-protocol".into()]
    } else {
      vec![]
    },
    ..Default::default()
  }
}

'''
    if anchor in s:
        mod_rs.write_text(s.replace(anchor, block + anchor, 1))
        print("  OK MOD-1a (fallback_options insertado)")
    else:
        check("MOD-1a", False, "not applied and the stock context changed — update the block")

# --- MOD-1b: fetch_options con fallback en vez de errores --------------------
s = mod_rs.read_text()
if "unwrap_or_else(fallback_options)" in s:
    print("  SKIP MOD-1b (fetch_options ya usa fallback)")
else:
    old = '''  let server_file = options_server_file(target, tauri_dir);
  let contents = read_to_string(&server_file).with_context(|| {
    format!(
      "failed to read {}; {}",
      server_file.display(),
      not_running()
    )
  })?;
  let info: OptionsServerInfo = serde_json::from_str(&contents)
    .with_context(|| format!("failed to parse {}", server_file.display()))?;

  let runtime = Runtime::new().context("failed to create async runtime")?;
  runtime.block_on(async move {
    let url = format!("ws://{}", info.addr)
      .parse()
      .context("failed to parse options server URL")?;
    let (tx, rx) = WsTransportClientBuilder::default()
      .build(url)
      .await
      .with_context(|| format!("failed to connect to the Tauri CLI; {}", not_running()))?;
    let client: Client = ClientBuilder::default().build_with_tokio(tx, rx);
    client
      .request("options", rpc_params![info.token])
      .await
      .context("failed to request options from the Tauri CLI")
  })
}'''
    new = '''  let server_file = options_server_file(target, tauri_dir);
  // When the IDE build runs without a `tauri ios|android dev|build`
  // parent process (e.g. opening Xcode directly and hitting Build), the
  // options server never ran, so the server file is missing or stale.
  // Fall back to standalone options instead of failing, keeping
  // standalone IDE builds functional.
  let Ok(contents) = read_to_string(&server_file) else {
    return Ok(fallback_options());
  };
  let Ok(info) = serde_json::from_str::<OptionsServerInfo>(&contents) else {
    return Ok(fallback_options());
  };

  let runtime = Runtime::new().context("failed to create async runtime")?;
  let options = runtime.block_on(async move {
    let url = match format!("ws://{}", info.addr).parse() {
      Ok(url) => url,
      Err(_) => return None,
    };
    let (tx, rx) = match WsTransportClientBuilder::default().build(url).await {
      Ok(transport) => transport,
      Err(_) => return None,
    };
    let client: Client = ClientBuilder::default().build_with_tokio(tx, rx);
    client
      .request("options", rpc_params![info.token])
      .await
      .ok()
  });
  Ok(options.unwrap_or_else(fallback_options))
}'''
    if old in s:
        s = s.replace(old, new, 1)
        # el closure not_running se queda sin usos: fuera (si no, warning)
        not_running = '''  let not_running = move || {
    format!(
      "the `tauri {0} dev` or `tauri {0} build` command must be running while {1} builds the app",
      target.command_name(),
      target.ide_name()
    )
  };

'''
        if "not_running()" not in s.replace(not_running, "") and not_running in s:
            s = s.replace(not_running, "", 1)
        mod_rs.write_text(s)
        print("  OK MOD-1b (fetch_options con fallback)")
    else:
        check("MOD-1b", False, "not applied and the stock fetch_options body changed — update the block")

# --- MOD-2: _iOS -> _Apple ----------------------------------------------------
for rel in ["src/mobile/ios/mod.rs", "src/mobile/ios/project.rs"]:
    p = v / rel
    s = p.read_text()
    if "_iOS" not in s:
        print(f"  SKIP MOD-2 ({rel} ya dice _Apple)")
    elif rel.endswith("mod.rs") and s.count('_iOS') == 2:
        p.write_text(s.replace('_iOS', '_Apple'))
        print(f"  OK MOD-2 ({rel}: 2 lookups)")
    elif rel.endswith("project.rs") and s.count('{}_iOS') == 1:
        p.write_text(s.replace('{}_iOS', '{}_Apple'))
        print(f"  OK MOD-2 ({rel}: 1 dir)")
    else:
        check(f"MOD-2 ({rel})", False, "hay _iOS en sitios inesperados — revisa a mano")

# --- MOD-3: replace simplificado de {{app.name}} ------------------------------
proj = v / "src/mobile/ios/project.rs"
s = proj.read_text()
if ".as_os_str()" in s:
    print("  SKIP MOD-3 (replace simplificado ya aplicado)")
else:
    old = '''      let mut components: Vec<_> = path.components().collect();
      let mut new_component = None;
      for component in &mut components {
        if let Component::Normal(c) = component {
          let c = c.to_string_lossy();
          if c.contains("{{app.name}}") {
            new_component.replace(OsString::from(
              &c.replace("{{app.name}}", config.app().name()),
            ));
            *component = Component::Normal(new_component.as_ref().unwrap());
            break;
          }
        }
      }
      let path = dest.join(components.iter().collect::<PathBuf>());'''
    new = '''      let path = path
        .as_os_str()
        .to_string_lossy()
        .replace("{{app.name}}", config.app().name());
      let path = dest.join(path);'''
    if old in s:
        s = s.replace(old, new, 1)
        s = s.replace("""use std::{
  ffi::OsString,
  fs::{OpenOptions, create_dir_all},
  path::{Component, PathBuf},
};""", "use std::fs::{OpenOptions, create_dir_all};", 1)
        proj.write_text(s)
        print("  OK MOD-3 (replace simplificado)")
    else:
        check("MOD-3", False, "the stock component loop changed — update the block")

if failures:
    print("\nBLOQUES SIN APLICAR:")
    print("\n".join(" - " + f for f in failures))
    sys.exit(1)
print("\nAll tweaks applied. Next: template overlay + build (see MODS.md).")
PY
