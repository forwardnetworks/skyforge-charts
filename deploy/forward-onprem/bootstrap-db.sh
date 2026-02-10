#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-}"
if [[ -z "${KUBECONFIG}" ]]; then
  echo "KUBECONFIG is required" >&2
  exit 1
fi

DB_NS="${DB_NS:-skyforge}"
DB_DEPLOY="${DB_DEPLOY:-db}"
FWD_NS="${FWD_NS:-forward}"

APP_USER="${APP_USER:-fwd_app}"
APP_DB="${APP_DB:-forward}"
APP_SECRET="${APP_SECRET:-postgres.fwd-pg-app.credentials}"

FDB_USER="${FDB_USER:-fwd_fdb}"
FDB_DB="${FDB_DB:-fwd_fdb}"
FDB_SECRET="${FDB_SECRET:-postgres.fwd-pg-fdb.credentials}"

base64_decode() {
  if base64 --help 2>/dev/null | grep -q -- '--decode'; then
    base64 --decode
    return
  fi
  # macOS
  base64 -D
}

get_secret_key() {
  local ns="$1" name="$2" key="$3"
  local b64
  b64="$(kubectl --kubeconfig "$KUBECONFIG" -n "$ns" get secret "$name" -o "jsonpath={.data.$key}" 2>/dev/null || true)"
  if [[ -z "$b64" ]]; then
    return 1
  fi
  printf '%s' "$b64" | base64_decode
}

rand_pw() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
    return
  fi
  python3 - <<'PY'
import secrets
print(secrets.token_hex(16))
PY
}

ensure_secret() {
  local ns="$1" name="$2" user="$3"
  local pw=""
  if pw="$(get_secret_key "$ns" "$name" password 2>/dev/null)"; then
    :
  else
    pw="$(rand_pw)"
  fi

  kubectl --kubeconfig "$KUBECONFIG" -n "$ns" create secret generic "$name" \
    --from-literal="user=$user" \
    --from-literal="password=$pw" \
    --dry-run=client -o yaml | kubectl --kubeconfig "$KUBECONFIG" apply -f - >/dev/null

  # Print password to stdout for operators who want to store it elsewhere.
  echo "$pw"
}

echo "Ensuring Forward namespace + PVCs exist..."
kubectl --kubeconfig "$KUBECONFIG" apply -f "$(dirname "$0")/pvc.yaml" >/dev/null

echo "Ensuring Forward DB credential secrets exist..."
APP_PW="$(ensure_secret "$FWD_NS" "$APP_SECRET" "$APP_USER")"
FDB_PW="$(ensure_secret "$FWD_NS" "$FDB_SECRET" "$FDB_USER")"

echo "Bootstrapping roles + DBs in Postgres (namespace=$DB_NS deploy=$DB_DEPLOY)..."
kubectl --kubeconfig "$KUBECONFIG" -n "$DB_NS" exec "deploy/$DB_DEPLOY" -- psql -U skyforge -d postgres -v ON_ERROR_STOP=1 <<SQL
-- Roles (idempotent) + required privileges for Forward bootstrap.
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${APP_USER}') THEN
    CREATE ROLE ${APP_USER} LOGIN PASSWORD '${APP_PW}';
  ELSE
    ALTER ROLE ${APP_USER} WITH LOGIN PASSWORD '${APP_PW}';
  END IF;
  ALTER ROLE ${APP_USER} CREATEDB CREATEROLE;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${FDB_USER}') THEN
    CREATE ROLE ${FDB_USER} LOGIN PASSWORD '${FDB_PW}';
  ELSE
    ALTER ROLE ${FDB_USER} WITH LOGIN PASSWORD '${FDB_PW}';
  END IF;
  ALTER ROLE ${FDB_USER} CREATEDB CREATEROLE;
END
\$\$;

-- Databases (idempotent). Use \\gexec to avoid errors if they already exist.
SELECT format('CREATE DATABASE %I OWNER %I', '${APP_DB}', '${APP_USER}')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${APP_DB}')\\gexec
SELECT format('CREATE DATABASE %I OWNER %I', '${FDB_DB}', '${FDB_USER}')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${FDB_DB}')\\gexec

-- Ensure ownership and CREATE rights (Postgres 15 tightened defaults).
ALTER DATABASE ${APP_DB} OWNER TO ${APP_USER};
GRANT ALL PRIVILEGES ON DATABASE ${APP_DB} TO ${APP_USER};
GRANT CREATE ON DATABASE ${APP_DB} TO ${APP_USER};

ALTER DATABASE ${FDB_DB} OWNER TO ${FDB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${FDB_DB} TO ${FDB_USER};
GRANT CREATE ON DATABASE ${FDB_DB} TO ${FDB_USER};
SQL

echo "Done."
echo "Forward app creds secret:   $FWD_NS/$APP_SECRET (user=$APP_USER)"
echo "Forward fdb creds secret:   $FWD_NS/$FDB_SECRET (user=$FDB_USER)"
