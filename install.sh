#!/usr/bin/env bash

set -euo pipefail

readonly DEFAULT_SKILL_SOURCE="https://github.com/processmission/oh-my-qemu"
readonly REQUIRED_EXCLUDES=(
    ".agents/"
    ".claude/skills/"
    ".oh-my-qemu/"
    "builds/"
    "skills-lock.json"
)
readonly MANAGED_INSTALL_PATHS=(
    ".agents/skills"
    ".claude/skills"
    "skills-lock.json"
)

resolve_skill_source() {
    if [[ -n "${OH_MY_QEMU_SKILL_SOURCE:-}" ]]; then
        printf '%s\n' "$OH_MY_QEMU_SKILL_SOURCE"
        return
    fi

    local script_path="${BASH_SOURCE[0]:-}"
    local script_dir=""
    if [[ -n "$script_path" ]]; then
        script_dir="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd -P)" ||
            script_dir=""
    fi
    if [[ -n "$script_dir" ]] && [[ -f "$script_dir/package.json" ]] &&
            [[ -d "$script_dir/.agents/skills" ]]; then
        printf '%s\n' "$script_dir"
        return
    fi

    printf '%s\n' "$DEFAULT_SKILL_SOURCE"
}

readonly SKILL_SOURCE="$(resolve_skill_source)"

usage() {
    cat <<'EOF'
Install all Oh My QEMU skills into a Git project without cloning this repository
manually.

Usage:
    install.sh [--target DIR] [skills add options]

Options:
    --target DIR       Existing Git project root (default: current directory)
    -s, --skill NAME   Install a subset instead of all skills
    -a, --agent NAME   Override the default Codex and Claude Code targets
    -h, --help         Show this help

Examples:
    curl -fsSL https://raw.githubusercontent.com/processmission/oh-my-qemu/main/install.sh | bash

    git clone https://github.com/processmission/oh-my-qemu.git
    cd oh-my-qemu
    ./install.sh --target /path/to/qemu
    ./install.sh --target /path/to/qemu --skill qemu-build

By default, all skills are installed non-interactively into project-local Codex
and Claude Code. -g and --global are rejected. When run from an Oh My QEMU
checkout, that checkout is used as the skill source. Other options are
forwarded to "npx skills add".
EOF
}

die() {
    printf 'oh-my-qemu: %s\n' "$*" >&2
    exit 1
}

for command_name in git npx grep tail; do
    command -v "$command_name" >/dev/null 2>&1 ||
        die "required command is unavailable: $command_name"
done

if [[ "${1:-}" == "install" ]]; then
    shift
fi

target_arg="$PWD"
forwarded=()
has_skill_arg=false
has_agent_arg=false
has_yes_arg=false

while (($# > 0)); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -g|--global|--global=*)
            die "global installation is disabled; choose a project with --target DIR"
            ;;
        -l|--list)
            die "list mode does not install; use npx skills add $DEFAULT_SKILL_SOURCE -l directly"
            ;;
        --all)
            die "--all targets every supported agent; omit it to install all skills into project-local Codex and Claude Code"
            ;;
        --target)
            (($# >= 2)) || die "--target requires a directory"
            [[ "$2" != -* ]] || die "--target requires a directory"
            target_arg="$2"
            shift 2
            ;;
        --target=*)
            target_arg="${1#--target=}"
            [[ -n "$target_arg" ]] || die "--target requires a directory"
            shift
            ;;
        -s|--skill)
            (($# >= 2)) || die "$1 requires at least one skill name"
            [[ "$2" != -* ]] || die "$1 requires at least one skill name"
            has_skill_arg=true
            forwarded+=("$1")
            shift
            ;;
        -a|--agent)
            (($# >= 2)) || die "$1 requires at least one agent name"
            [[ "$2" != -* ]] || die "$1 requires at least one agent name"
            has_agent_arg=true
            forwarded+=("$1")
            shift
            ;;
        -y|--yes)
            has_yes_arg=true
            forwarded+=("$1")
            shift
            ;;
        *)
            forwarded+=("$1")
            shift
            ;;
    esac
done

[[ -d "$target_arg" ]] || die "target is not an existing directory: $target_arg"
target_dir="$(cd "$target_arg" && pwd -P)"

if ! inside_worktree="$(git -C "$target_dir" rev-parse --is-inside-work-tree 2>/dev/null)" ||
        [[ "$inside_worktree" != "true" ]]; then
    die "target is not inside a Git worktree: $target_dir"
fi
if ! git_root="$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    die "could not resolve the Git project root for: $target_dir"
fi
git_root="$(cd "$git_root" && pwd -P)"
[[ "$target_dir" == "$git_root" ]] ||
    die "target must be the Git project root: $git_root"

tracked_install_paths="$(git -C "$target_dir" ls-files -- "${MANAGED_INSTALL_PATHS[@]}")"
if [[ -n "$tracked_install_paths" ]]; then
    printf 'oh-my-qemu: target already tracks installer-managed paths:\n' >&2
    while IFS= read -r tracked_path; do
        printf '  %s\n' "$tracked_path" >&2
    done <<<"$tracked_install_paths"
    die "untrack or preserve those paths manually before using the project-local installer"
fi

printf 'Installing Oh My QEMU skills into %s\n' "$target_dir"
install_command=(npx --yes skills add "$SKILL_SOURCE")
if ((${#forwarded[@]} > 0)); then
    install_command+=("${forwarded[@]}")
fi
if [[ "$has_skill_arg" == false ]]; then
    install_command+=(--skill '*')
fi
if [[ "$has_agent_arg" == false ]]; then
    install_command+=(--agent codex claude-code)
fi
if [[ "$has_yes_arg" == false ]]; then
    install_command+=(-y)
fi

if [[ -r /dev/tty ]] && (: </dev/tty) 2>/dev/null; then
    (cd "$target_dir" && "${install_command[@]}" </dev/tty)
else
    (cd "$target_dir" && "${install_command[@]}" </dev/null)
fi

exclude_file="$(git -C "$target_dir" rev-parse --git-path info/exclude)"
if [[ "$exclude_file" != /* ]]; then
    exclude_file="$target_dir/$exclude_file"
fi
mkdir -p "$(dirname "$exclude_file")"
touch "$exclude_file"

missing_excludes=()
for entry in "${REQUIRED_EXCLUDES[@]}"; do
    bare_entry="${entry%/}"
    pattern="${bare_entry//./\\.}"
    if [[ "$entry" == */ ]]; then
        exclude_pattern="^/?${pattern}/?$"
    else
        exclude_pattern="^/?${pattern}$"
    fi
    if ! grep -Eq "$exclude_pattern" "$exclude_file"; then
        missing_excludes+=("$entry")
    fi
done

if ((${#missing_excludes[@]} > 0)); then
    if [[ -s "$exclude_file" ]] && [[ -n "$(tail -c 1 "$exclude_file")" ]]; then
        printf '\n' >>"$exclude_file"
    fi
    for entry in "${missing_excludes[@]}"; do
        printf '%s\n' "$entry" >>"$exclude_file"
    done
fi

for entry in "${REQUIRED_EXCLUDES[@]}"; do
    probe="$entry"
    if [[ "$entry" == */ ]]; then
        probe="${entry}.oh-my-qemu-install-probe"
    fi
    git -C "$target_dir" check-ignore --no-index -q "$probe" ||
        die "could not verify repository-local Git exclude for $entry"
done

visible_install_paths="$(
    git -C "$target_dir" status --short --untracked-files=all -- \
        "${MANAGED_INSTALL_PATHS[@]}"
)"
if [[ -n "$visible_install_paths" ]]; then
    printf 'oh-my-qemu: installation left managed paths visible to Git:\n%s\n' \
        "$visible_install_paths" >&2
    die "review the target repository before continuing"
fi

printf 'Project-local installation complete.\n'
printf 'Git exclude: %s\n' "$exclude_file"
printf 'Excluded: %s\n' "${REQUIRED_EXCLUDES[*]}"
printf 'Lockfile: %s\n' "$target_dir/skills-lock.json"
