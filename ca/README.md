# Private CA for the IAM Roles Anywhere trust anchor

The trust anchor must be a **CA certificate whose private key you control**,
because the worker presents a leaf cert that *you* sign and AWS trusts anything
chaining to it.

> Your existing `mylward.uk` (Let's Encrypt) cert **cannot** be used: it's a
> *leaf* cert and you don't hold Let's Encrypt's CA key, so you can't mint
> worker certs from it. Pointing the trust anchor at the LE CA would let *any*
> LE cert assume the role — a non-starter.

This is a tiny, one-off, **offline** CA. No AWS Private CA (that's ~$400/mo).

## 1. Create the CA (do this on an offline / trusted machine; keep `ca.key` safe)
```bash
# CA private key (KEEP OFFLINE — this is the root of trust)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out ca.key

# Self-signed CA certificate (10 years).
# The CA:TRUE basic constraint + keyCertSign are REQUIRED by Roles Anywhere;
# a plain `req -x509` doesn't always add them, which causes:
#   ValidationException: Incorrect basic constraints for CA certificate
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/CN=paperless-ai-home-ca/O=mylward" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out ca.crt

# Verify the constraints are present before feeding it to AWS:
openssl x509 -in ca.crt -noout -text | grep -A1 'Basic Constraints'
#   X509v3 Basic Constraints: critical
#       CA:TRUE
```
Feed `ca.crt` to Terraform (the CA cert only):
```bash
export TF_VAR_worker_ca_cert_pem="$(cat ca.crt)"
# or add to a NON-committed terraform.tfvars
```

## 2. Issue the worker leaf cert (short-lived; rotate)
The CN must match `worker_cert_subject_cn` (default `paperless-ai-worker`),
which the role's trust policy enforces.
```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out worker.key
openssl req -new -key worker.key -subj "/CN=paperless-ai-worker" -out worker.csr

# Leaf extensions: Roles Anywhere REQUIRES the end-entity cert to be a
# non-CA cert with Digital Signature key usage. `openssl x509 -req` adds NO
# extensions on its own, so they must be supplied via -extfile.
cat > worker.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
EOF

openssl x509 -req -in worker.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 90 -sha256 -extfile worker.ext -out worker.crt

# Verify: should show CA:FALSE and "Digital Signature".
openssl x509 -in worker.crt -noout -text | grep -A1 -E 'Basic Constraints|Key Usage'
```

## 3. Install on the home server (NOT in git)
```bash
sudo install -d -m 0700 /etc/aiworker
sudo install -m 0600 -o root -g root worker.crt /etc/aiworker/worker.crt
sudo install -m 0600 -o root -g root worker.key /etc/aiworker/worker.key
# point AI_CERT_DIR=/etc/aiworker in paperless/.env (default is ./ai-worker/certs)
```

## 4. Rotate (every ~90 days)
Re-run step 2 and re-install step 3. The CA cert / trust anchor is unchanged, so
no AWS change is needed. Automate with a cron + a short bash script if desired.

## Security notes
- `ca.key` never leaves your offline/trusted store; only `ca.crt` goes to AWS.
- `worker.key` is `0600`, root-owned, mounted **read-only** into the container.
- The worker role can only `bedrock:InvokeModel` on one model ARN, so a stolen
  `worker.key` buys an attacker nothing but inference on that one model.
- **Never commit** `*.key`, `*.crt`, `*.csr`, `*.srl`, or `terraform.tfvars`.
  