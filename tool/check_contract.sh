#!/usr/bin/env bash
# Comprueba que contract/ es exactamente lo que hay hoy en notify_web.
#
# Uso: tool/check_contract.sh
# Ruta a notify_web: $NOTIFY_WEB o, por defecto, ../notify_web.
# Si no hay notify_web disponible, comprueba al menos que contract/ es íntegro
# respecto a su propio CHECKSUMS (lo que permite ejecutarlo sin la fuente).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="${NOTIFY_WEB:-$ROOT/../notify_web}"
DEST="$ROOT/contract"
fail=0

if [[ -f "$WEB/docs/api/openapi.yaml" ]]; then
	compare() {
		local rel="$1"
		if ! diff -q "$WEB/$rel" "$DEST/${rel#docs/api/}" >/dev/null; then
			echo "Difiere de notify_web: $rel" >&2
			fail=1
		fi
	}
	compare "docs/api/openapi.yaml"
	compare "docs/api/vectors/README.md"
	for f in "$WEB"/docs/api/vectors/*.json; do
		compare "docs/api/vectors/$(basename "$f")"
	done
else
	echo "notify_web no disponible en $WEB; se comprueba la integridad de contract/ (CHECKSUMS)" >&2
	if [[ -f "$DEST/CHECKSUMS" ]]; then
		(cd "$DEST" && sha256sum -c CHECKSUMS >/dev/null) || fail=1
	else
		echo "Falta $DEST/CHECKSUMS" >&2
		fail=1
	fi
fi

if [[ "$fail" -ne 0 ]]; then
	echo "El contrato NO coincide. Ejecuta tool/sync_contract.sh y revisa el diff." >&2
	exit 1
fi
echo "Contrato correcto."
