#!/bin/bash
SERVICE="paperless-api-token"
CONF_FILE="$HOME/.config/paperless-upload/url"
SCAN_DIR="$HOME/Documents/Paperless-ngx/inbox"
LOG="$HOME/Library/Logs/paperless-upload.log"

if [ "$1" = "--setup" ] || [ "$1" = "--set-token" ]; then
    read -rp "Paperless Basis-URL (z.B. https://paperless.example.com): " base_url
    base_url="${base_url%/}"
    [ -z "$base_url" ] && { echo "Abbruch: keine URL."; exit 1; }

    read -rsp "Paperless API-Token eingeben: " token
    echo
    [ -z "$token" ] && { echo "Abbruch: leerer Token."; exit 1; }

    code=$(curl -sSL -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "Authorization: Token $token" "$base_url/api/documents/?page_size=1" || echo "000")
    if [ "$code" != "200" ]; then
        echo "Token ungueltig oder Server nicht erreichbar (HTTP $code). Nichts gespeichert."
        exit 1
    fi

    mkdir -p "$(dirname "$CONF_FILE")"
    printf '%s\n' "$base_url" > "$CONF_FILE"
    chmod 600 "$CONF_FILE"
    security add-generic-password -s "$SERVICE" -a "$USER" -w "$token" -T /usr/bin/security -U \
        && echo "URL in $CONF_FILE und Token im Schluesselbund gespeichert." \
        || { echo "Fehler beim Speichern im Schluesselbund."; exit 1; }
    exit 0
fi

TOKEN=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null)
BASE_URL=$(cat "$CONF_FILE" 2>/dev/null)

if [ -z "$TOKEN" ] || [ -z "$BASE_URL" ]; then
    echo "$(date): FEHLER: Konfiguration unvollstaendig. Bitte ausfuehren: paperless-upload.sh --setup" >>"$LOG"
    osascript <<'EOF'
display dialog "Paperless-Upload: URL oder API-Token fehlt.

Bitte einmalig im Terminal ausfuehren:

~/.local/bin/paperless-upload.sh --setup" \
    buttons {"OK"} default button 1 \
    with icon stop \
    with title "Paperless Upload"
EOF
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"
    [ -t 1 ] && echo "$*"
}

shopt -s nullglob
files=( "$SCAN_DIR"/*.pdf )

if [ ${#files[@]} -eq 0 ]; then
    log "INFO: Keine PDFs in $SCAN_DIR gefunden."
    exit 0
fi

log "START: ${#files[@]} Datei(en) in $SCAN_DIR gefunden."
ok=0; fail=0; skip=0

for f in "${files[@]}"; do
    name=$(basename "$f")
    log ">> Verarbeite: $name"

    s1=$(stat -f%z "$f"); sleep 2
    s2=$(stat -f%z "$f")
    if [ "$s1" != "$s2" ]; then
        log "   UEBERSPRUNGEN: $name wird noch geschrieben ($s1 -> $s2 Bytes)."
        skip=$((skip+1))
        continue
    fi

    response=$(mktemp)
    code=$(curl -sS -o "$response" -w "%{http_code}" \
            -H "Authorization: Token $TOKEN" \
            -F "document=@$f" \
            "$BASE_URL/api/documents/post_document/" 2>>"$LOG" || echo "000")
    body=$(cat "$response")
    rm -f "$response"

    if [ "$code" = "200" ]; then
        rm "$f"
        log "   OK: $name hochgeladen (HTTP 200, Task: $body), lokale Datei geloescht."
        ok=$((ok+1))
    else
        log "   FEHLER: $name nicht hochgeladen (HTTP $code, Antwort: $body). Datei bleibt im Ordner."
        fail=$((fail+1))
    fi
done

log "FERTIG: $ok hochgeladen, $fail fehlgeschlagen, $skip uebersprungen."
