#!/usr/bin/env bash
# Generate a fresh worker leaf cert (correct extensions for IAM Roles Anywhere)
# and install it on the homelab. Run from infra/ca/ where ca.crt + ca.key live.
# Use for the initial install AND every ~90 day rotation. ca.key is untouched;
# AWS needs no changes (the trust anchor trusts the CA, not the leaf).
#
# Usage:  ./rotate-worker-cert.sh user@homelab [CN] [days]
#   e.g.  ./rotate-worker-cert.sh peter@192.168.1.215
set -euo pipefail

DEST="${1:?usage: ./rotate-worker-cert.sh user@host [CN] [days]}"
CN="${2:-paperless-ai-worker}"   # must match worker_cert_subject_cn in tfvars
DAYS="${3:-90}"

[[ -f ca.crt && -f ca.key ]] || { echo "ca.crt/ca.key not found — run from infra/ca/"; exit 1; }

echo "==> generating leaf (CN=${CN}, ${DAYS}d)"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out worker.key
openssl req -new -key worker.key -subj "/CN=${CN}" -out worker.csr
cat > worker.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
EOF
openssl x509 -req -in worker.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days "${DAYS}" -sha256 -extfile worker.ext -out worker.crt

echo "==> verify"
openssl x509 -in worker.crt -noout -text | grep -A1 -E 'Basic Constraints|Key Usage'

echo "==> copying to ${DEST}:/tmp"
scp worker.crt worker.key "${DEST}:/tmp/"

# Owned by the worker container's non-root user (uid 10001) so it can read them;
# 0600/0700 keeps access to just that uid + root.
echo "==> installing to /etc/aiworker (0600, uid 10001) and cleaning up"
ssh "${DEST}" 'sudo install -d -m 0700 -o 10001 -g 10001 /etc/aiworker && \
  sudo install -m 0600 -o 10001 -g 10001 /tmp/worker.crt /etc/aiworker/worker.crt && \
  sudo install -m 0600 -o 10001 -g 10001 /tmp/worker.key /etc/aiworker/worker.key && \
  shred -u /tmp/worker.crt /tmp/worker.key'

# local temp scratch (keep nothing lying around)
rm -f worker.csr worker.ext
echo "==> done. Restart the worker to pick it up:"
echo "    ssh ${DEST} 'cd /home/peter/docker/paperless && docker compose restart ai-worker'"
