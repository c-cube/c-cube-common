#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-crush.sh [OPTIONS] [--] [CRUSH_ARGS...]

Options:
  --expose=<path>       Mount <path> read-only into the container at the same location.
                        Repeatable.
  --expose-rw=<path>    Mount <path> read-write into the container at the same location.
                        Repeatable.
  --help                Show this message.

All other arguments are forwarded to crush inside the container.

Environment:
  CRUSH_EXTRA_MOUNTS   Space-separated list of extra -v mount specs (appended last).
EOF
  exit 0
}

mounts=()
expose_rw=()
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expose=*)
      p="${1#--expose=}"
      p="$(realpath -m "$p")"
      mounts+=(-v "$p:$p:ro")
      shift
      ;;
    --expose-rw=*)
      p="${1#--expose-rw=}"
      p="$(realpath -m "$p")"
      expose_rw+=(-v "$p:$p")
      shift
      ;;
    --help)
      usage
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

# --- core mounts ---
mounts+=(
  -v "$PWD:/work/:z"
  -v "$HOME/.gitconfig:$HOME/.gitconfig:ro"
  -v "$HOME/.config/git:$HOME/.config/git:ro"
  -v "$HOME/.config/crush:$HOME/.config/crush:z"
)

# --- toolchain mounts + PATH ---
path_extra=()

add_ro_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    mounts+=(-v "$dir:$dir:ro")
    return 0
  fi
  return 1
}

add_bin_to_path() {
  local dir="$1"
  if [ -d "$dir" ]; then
    path_extra+=("$dir")
  fi
}

# opam (mount the whole thing, add current switch to PATH)
if add_ro_dir "$HOME/.opam"; then
  if [ -n "${OPAMSWITCH:-}" ] && [ -d "$HOME/.opam/${OPAMSWITCH}/bin" ]; then
    path_extra+=("$HOME/.opam/${OPAMSWITCH}/bin")
  elif [ -d "$HOME/.opam/default/bin" ]; then
    path_extra+=("$HOME/.opam/default/bin")
  fi
fi

add_ro_dir "$HOME/.cargo"      && add_bin_to_path "$HOME/.cargo/bin"
add_ro_dir "$HOME/go"          && add_bin_to_path "$HOME/go/bin"
add_ro_dir "$HOME/bin"         && add_bin_to_path "$HOME/bin"
add_ro_dir "$HOME/.local"      && add_bin_to_path "$HOME/.local/bin"
add_ro_dir "$HOME/.nimble"     && add_bin_to_path "$HOME/.nimble/bin"
add_ro_dir "$HOME/.npm-packages" && add_bin_to_path "$HOME/.npm-packages/bin"
add_ro_dir "$HOME/.elan"       && add_bin_to_path "$HOME/.elan/bin"

# extra mounts from env
if [ -n "${CRUSH_EXTRA_MOUNTS:-}" ]; then
  IFS=' ' read -ra extra <<< "$CRUSH_EXTRA_MOUNTS"
  mounts+=("${extra[@]}")
fi

# build final PATH
container_path=""
for p in "${path_extra[@]}"; do
  container_path="${container_path}${p}:"
done
container_path="${container_path}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exec docker run --rm -it \
  --cpus=1 \
  --memory=4g \
  --user "$(id -u):$(id -g)" \
  -e "HOME=$HOME" \
  -e "PATH=$container_path" \
  "${mounts[@]}" \
  "${expose_rw[@]}" \
  crush-docker "${extra_args[@]}"
