#!/usr/bin/env python3
"""
update-env.py — UDMS environment manager

Usage:
  python3 update-env.py            # update computed vars, preserve secrets
  python3 update-env.py --init     # first-time setup, prompt for all secrets
  python3 update-env.py --prompt TORBOX_API_KEY [VAR2 ...]  # re-prompt specific vars

Must be run from the scripts/ directory (same as udms.sh).
"""

import argparse
import os
import sys


# ---------------------------------------------------------------------------
# Paths (relative to scripts/ directory, same as udms.sh)
# ---------------------------------------------------------------------------

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT    = os.path.dirname(SCRIPT_DIR)
CONFIG_ENV   = os.path.join(SCRIPT_DIR, "config.env")
ENV_EXAMPLE  = os.path.join(REPO_ROOT, ".env.example")

# These are resolved after we load config.env
def get_env_file(config: dict) -> str:
    docker_root = config.get("DOCKER_ROOT", "")
    if not docker_root or "$" in docker_root:
        # Fallback: DOCKER_ROOT didn't expand properly, derive from HOME
        docker_root = os.path.join(os.path.expanduser("~"), "docker")
    return os.path.join(docker_root, ".env")


# ---------------------------------------------------------------------------
# Variables that are always recomputed — never preserved from old .env
# ---------------------------------------------------------------------------

COMPUTED_VARS = {
    "PUID", "PGID", "HOSTNAME", "USERDIR",
    "DOCKERDIR", "SECRETSDIR",
    "HOMEPAGE_VAR_PORTAINER_URL",
    "HOMEPAGE_VAR_DOZZLE_URL",
    "HOMEPAGE_VAR_JELLYFIN_URL",
    "HOMEPAGE_VAR_QBITTORRENT_URL",
    "HOMEPAGE_VAR_SONARR_URL",
    "HOMEPAGE_VAR_RADARR_URL",
    "HOMEPAGE_VAR_PROWLARR_URL",
    "HOMEPAGE_VAR_BAZARR_URL",
    "HOMEPAGE_VAR_HOMARR_URL",
    "HOMEPAGE_VAR_DECYPHARR_URL",
    "STREMTHRU_STORE_AUTH",
}

# ---------------------------------------------------------------------------
# Secrets — prompted on --init or --prompt, never auto-overwritten
# ---------------------------------------------------------------------------

SECRETS = [
    "TORBOX_API_KEY",
    "PLEX_CLAIM",
    "DOMAINNAME_HS",
    "HOMEPAGE_VAR_JELLYFIN_API_KEY",
    "HOMEPAGE_VAR_SONARR_API_KEY",
    "HOMEPAGE_VAR_RADARR_API_KEY",
    "HOMEPAGE_VAR_PROWLARR_API_KEY",
    "HOMEPAGE_VAR_QBITTORRENT_PASSWORD",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_shell_env(path: str) -> dict:
    """
    Parse a shell env file directly without subprocess.
    Handles simple KEY=value and KEY=$OTHER_KEY style references.
    """
    if not os.path.isfile(path):
        print(f"ERROR: {path} not found.", file=sys.stderr)
        sys.exit(1)

    env = {}
    with open(path) as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "=" not in stripped:
                continue
            key, _, val = stripped.partition("=")
            key = key.strip()
            val = val.strip()

            # Expand $HOME and ${HOME}
            val = val.replace("$HOME", os.path.expanduser("~"))
            val = val.replace("${HOME}", os.path.expanduser("~"))

            # Expand references to already-parsed keys e.g. $DOCKER_ROOT
            for k, v in env.items():
                val = val.replace(f"${{{k}}}", v)
                val = val.replace(f"${k}", v)

            env[key] = val

    return env


def parse_env_file(path: str) -> "list[tuple]":
    """
    Parse an .env file preserving comments and blank lines.
    Returns a list of (type, content) tuples:
      ('comment', '# some comment')
      ('blank', '')
      ('var', ('KEY', 'value'))
    """
    entries = []
    if not os.path.isfile(path):
        return entries
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            stripped = line.strip()
            if not stripped:
                entries.append(("blank", ""))
            elif stripped.startswith("#"):
                entries.append(("comment", line))
            elif "=" in stripped:
                key, _, val = stripped.partition("=")
                entries.append(("var", (key.strip(), val.strip())))
            else:
                entries.append(("comment", line))  # unrecognised, preserve
    return entries


def entries_to_dict(entries: list) -> dict:
    return {k: v for t, (k, v) in (e for e in entries if e[0] == "var") 
            if True}


def write_env_file(path: str, entries: list) -> None:
    with open(path, "w") as f:
        for kind, content in entries:
            if kind == "blank":
                f.write("\n")
            elif kind == "comment":
                f.write(content + "\n")
            elif kind == "var":
                key, val = content
                f.write(f"{key}={val}\n")


def prompt_secret(key: str, current: str) -> str:
    display = f" [{current}]" if current else " [empty]"
    val = input(f"  {key}{display}: ").strip()
    return val if val else current


def compute_vars(config: dict, existing_vars: dict = None) -> dict:
    """Compute all auto-derived variables from config.env values."""
    existing_vars = existing_vars or {}
    docker_root = config.get("DOCKER_ROOT", "")
    if not docker_root or "$" in docker_root:
        docker_root = os.path.join(os.path.expanduser("~"), "docker")
    server_ip = config.get("SERVER_IP", "")

    # Derive STREMTHRU_STORE_AUTH from the existing TORBOX_API_KEY secret.
    # Format: <username>:torbox=<api_key>  — username is the system user.
    torbox_key = existing_vars.get("TORBOX_API_KEY", "")
    stremthru_username = os.path.basename(os.path.expanduser("~"))
    stremthru_store_auth = (
        f"{stremthru_username}:torbox={torbox_key}" if torbox_key else ""
    )

    return {
        "PUID":                          str(os.getuid()),
        "PGID":                          str(os.getgid()),
        "HOSTNAME":                      os.uname().nodename,
        "USERDIR":                       os.path.expanduser("~"),
        "DOCKERDIR":                     docker_root,
        "SECRETSDIR":                    os.path.join(docker_root, "secrets"),
        "HOMEPAGE_VAR_PORTAINER_URL":    f"http://{server_ip}:9000",
        "HOMEPAGE_VAR_DOZZLE_URL":       f"http://{server_ip}:8082",
        "HOMEPAGE_VAR_JELLYFIN_URL":     f"http://{server_ip}:8096",
        "HOMEPAGE_VAR_QBITTORRENT_URL":  f"http://{server_ip}:8081",
        "HOMEPAGE_VAR_SONARR_URL":       f"http://{server_ip}:8989",
        "HOMEPAGE_VAR_RADARR_URL":       f"http://{server_ip}:7878",
        "HOMEPAGE_VAR_PROWLARR_URL":     f"http://{server_ip}:9696",
        "HOMEPAGE_VAR_BAZARR_URL":       f"http://{server_ip}:6767",
        "HOMEPAGE_VAR_HOMARR_URL":       f"http://{server_ip}:7575",
        "HOMEPAGE_VAR_DECYPHARR_URL":    f"http://{server_ip}:8282",
        "STREMTHRU_STORE_AUTH":          stremthru_store_auth,
    }


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def update_env(init: bool = False, prompt_keys: list = None) -> None:
    prompt_keys = prompt_keys or []

    # 1. Load config.env (user settings)
    config = load_shell_env(CONFIG_ENV)

    env_file = get_env_file(config)
    is_new   = not os.path.isfile(env_file)

    if is_new and not init:
        print(f".env not found at {env_file}. Running in --init mode.")
        init = True

    # 2. Parse existing .env (preserves comments/structure)
    existing_entries = parse_env_file(env_file) if not is_new else []
    existing_vars    = {k: v for t, c in existing_entries 
                        if t == "var" for k, v in [c]}

    # 3. Compute fresh values
    computed = compute_vars(config, existing_vars)

    # 4. Build the user-config vars from config.env
    user_config_vars = {
        "TZ":       config.get("TZ", ""),
        "SERVER_IP": config.get("SERVER_IP", ""),
        "DATADIR":  config.get("DATADIR", ""),
        "LOCAL_IPS": "127.0.0.1/32,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12",
    }

    # 5. Handle secrets
    secrets = {}
    for key in SECRETS:
        current = existing_vars.get(key, "")
        if init or key in prompt_keys:
            print(f"\nSecret: {key}")
            secrets[key] = prompt_secret(key, current)
        else:
            # Preserve whatever is already set
            secrets[key] = current

    # 6. Merge everything into a final dict
    # Priority: computed > user_config > secrets > existing (for unknowns)
    # Re-run compute_vars now that secrets are resolved (e.g. TORBOX_API_KEY may
    # have just been prompted for the first time via --init).
    computed = compute_vars(config, {**existing_vars, **secrets})
    final_vars = {**existing_vars, **user_config_vars, **secrets, **computed}

    # 7. If new file, build from .env.example structure + dynamic block
    if is_new:
        example_entries = parse_env_file(ENV_EXAMPLE)
        # Start with .env.example as the base (gives us all the comments)
        new_entries = list(example_entries)
        # Append the dynamic block
        new_entries.append(("blank", ""))
        new_entries.append(("comment", "##### DYNAMIC — managed by update-env.py"))
        for key, val in {**user_config_vars, **computed, **secrets}.items():
            new_entries.append(("var", (key, val)))
        write_env_file(env_file, new_entries)
        print(f"\n✓ Created {env_file}")

    else:
        # 8. Update existing file in-place
        updated_entries = []
        updated_keys    = set()

        for kind, content in existing_entries:
            if kind != "var":
                updated_entries.append((kind, content))
                continue

            key, old_val = content
            new_val = final_vars.get(key, old_val)
            updated_keys.add(key)

            if key in COMPUTED_VARS or key in user_config_vars:
                if new_val != old_val:
                    print(f"  updated  {key}={new_val}  (was: {old_val})")
                updated_entries.append(("var", (key, new_val)))
            else:
                # Preserve existing value (secrets + unknown user vars)
                updated_entries.append(("var", (key, old_val)))

        # Append any new computed/config vars not yet in the file
        new_keys = set(final_vars) - updated_keys
        if new_keys:
            updated_entries.append(("blank", ""))
            updated_entries.append(("comment", "##### ADDED by update-env.py"))
            for key in sorted(new_keys):
                if key in {**computed, **user_config_vars, **secrets}:
                    print(f"  added    {key}={final_vars[key]}")
                    updated_entries.append(("var", (key, final_vars[key])))

        write_env_file(env_file, updated_entries)
        print(f"\n✓ Updated {env_file}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="UDMS environment manager — updates ~/docker/.env from config.env"
    )
    parser.add_argument(
        "--init",
        action="store_true",
        help="First-time setup: prompt for all secrets and create .env"
    )
    parser.add_argument(
        "--prompt",
        nargs="+",
        metavar="VAR",
        help="Re-prompt for specific secret(s), e.g. --prompt TORBOX_API_KEY"
    )
    args = parser.parse_args()

    print("UDMS env manager")
    print("================")
    update_env(init=args.init, prompt_keys=args.prompt or [])


if __name__ == "__main__":
    main()
