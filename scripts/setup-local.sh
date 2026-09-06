#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
aws_binary=$(command -v aws)
for local_path in "$HOME" "$aws_binary"; do
  [[ "$local_path" =~ ^/[a-zA-Z0-9_./-]+$ ]] || { printf 'SSH setup requires HOME and AWS CLI paths without spaces or shell metacharacters.\n' >&2; exit 1; }
done
asobi_check_account
instance=$(asobi_instance)
public_key=$(jq -er '.ssh_public_key_path' "$ASOBI_CONFIG")
public_key=${public_key/#\~/$HOME}
[[ "$public_key" == /*.pub ]] || { printf 'Use an absolute or ~/ public key path ending in .pub.\n' >&2; exit 1; }
key=${public_key%.pub}
[[ -f "$key" && -f "$key.pub" ]] || { printf 'Create the dedicated SSH key first; see README.\n' >&2; exit 1; }

# Install the official AWS plugin into the current user's directory, without sudo.
plugin="$HOME/.local/bin/session-manager-plugin"
if [[ ! -x "$plugin" ]]; then
  [[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { printf 'Install the AWS Session Manager plugin for your OS first.\n' >&2; exit 1; }
  scratch=$(mktemp -d /tmp/asobi-ssm-plugin.XXXXXX)
  curl --fail --show-error --silent --location --retry 3 \
    https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb \
    -o "$scratch/plugin.deb"
  dpkg-deb --extract "$scratch/plugin.deb" "$scratch/extracted"
  install -d -m 0755 "$HOME/.local/bin"
  install -m 0755 "$scratch/extracted/usr/local/sessionmanagerplugin/bin/session-manager-plugin" "$plugin"
fi

install -d -m 0700 "$HOME/.ssh/config.d"
# A specific host precedes any existing Host * defaults. Preserve the user's config.
config="$HOME/.ssh/config"
include="Include ~/.ssh/config.d/$ASOBI_NAME.conf"
if [[ -f "$config" ]] && grep -Eq "^Host[[:space:]]+$ASOBI_NAME([[:space:]]|$)" "$config"; then
  printf 'Existing asobi-dev Host block found in %s; resolve it before continuing.\n' "$config" >&2
  exit 1
fi
if [[ ! -f "$config" ]] || ! grep -Fxq "$include" "$config"; then
  staged=$(mktemp "$HOME/.ssh/asobi-config.XXXXXX")
  printf '%s\n\n' "$include" > "$staged"
  if [[ -f "$config" ]]; then
    cp -p "$config" "$HOME/.ssh/config.before-asobi.$(date +%Y%m%d%H%M%S)"
    sed -n '1,$p' "$config" >> "$staged"
  fi
  install -m 0600 "$staged" "$config"
fi
printf '%s\n' \
  "Host $ASOBI_NAME" \
  "    HostName $instance" \
  '    User ubuntu' \
  "    IdentityFile \"$key\"" \
  '    IdentitiesOnly yes' \
  '    ForwardAgent no' \
  '    ServerAliveInterval 30' \
  '    ServerAliveCountMax 3' \
  "    ProxyCommand env PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin $aws_binary --profile $ASOBI_PROFILE --region $ASOBI_REGION ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p" \
  > "$HOME/.ssh/config.d/$ASOBI_NAME.conf"
chmod 0600 "$HOME/.ssh/config.d/$ASOBI_NAME.conf"
"$plugin" --version
printf 'Configured ssh %s for %s.\n' "$ASOBI_NAME" "$instance"
