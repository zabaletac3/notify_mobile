#!/usr/bin/env bash
# Copia el contrato (OpenAPI + vectores) desde notify_web a contract/.
#
# Uso: tool/sync_contract.sh
# Ruta a notify_web: $NOTIFY_WEB o, por defecto, ../notify_web.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="${NOTIFY_WEB:-$ROOT/../notify_web}"
DEST="$ROOT/contract"

if [[ ! -f "$WEB/docs/api/openapi.yaml" ]]; then
	echo "No se encuentra el contrato en $WEB (define NOTIFY_WEB)" >&2
	exit 1
fi

mkdir -p "$DEST/vectors"
cp "$WEB/docs/api/openapi.yaml" "$DEST/openapi.yaml"
cp "$WEB"/docs/api/vectors/*.json "$DEST/vectors/"
cp "$WEB/docs/api/vectors/README.md" "$DEST/vectors/README.md"

# Integridad de contract/ para poder comprobarlo sin notify_web presente.
( cd "$DEST" && find . -type f ! -name CHECKSUMS -print0 | sort -z | xargs -0 sha256sum > CHECKSUMS )

echo "Contrato sincronizado en $DEST:"
ls -1 "$DEST" | sed 's/^/  /'
ls -1 "$DEST/vectors" | sed 's/^/  vectors\//'
