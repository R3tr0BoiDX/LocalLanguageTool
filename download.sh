#!/usr/bin/env bash
# Download LanguageTool n-gram data into $NGRAMS_DIR/<lang>/.
#
# Usage: ./download.sh [lang ...]      (default: de en)
#
# Already present languages are skipped, interrupted downloads are resumed.
set -euo pipefail

BASE_URL="https://languagetool.org/download/ngram-data"

# Other languages (es, fr, nl) are listed at the URL above and can be added here.
declare -A FILES=(
  [de]=ngrams-de-20150819.zip
  [en]=ngrams-en-20150817.zip
)

cd "$(dirname "$0")"

# Pick up NGRAMS_DIR from .env if not set in the environment.
if [[ -z "${NGRAMS_DIR:-}" && -f .env ]]; then
  NGRAMS_DIR=$(sed -n 's/^NGRAMS_DIR=//p' .env | tail -n1)
fi
NGRAMS_DIR=${NGRAMS_DIR:-./ngrams}

langs=("$@")
[[ ${#langs[@]} -eq 0 ]] && langs=(de en)

for lang in "${langs[@]}"; do
  if [[ -z "${FILES[$lang]:-}" ]]; then
    echo "Unknown language '$lang'. Available: ${!FILES[*]}" >&2
    exit 1
  fi
done

unzip_to() {
  if command -v unzip >/dev/null; then
    unzip -q "$1" -d "$2"
  else
    python3 -m zipfile -e "$1" "$2"
  fi
}

mkdir -p "$NGRAMS_DIR"

for lang in "${langs[@]}"; do
  target="$NGRAMS_DIR/$lang"
  if [[ -d "$target" ]]; then
    echo "[$lang] already present in $target, skipping"
    continue
  fi

  zip="$NGRAMS_DIR/${FILES[$lang]}"
  url="$BASE_URL/${FILES[$lang]}"

  # Zip and extracted data coexist until the zip is removed, so we need
  # roughly twice the archive size (minus what is already downloaded).
  size=$(curl -sSfLI "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:" {print $2}' | tail -n1)
  if [[ -n "$size" ]]; then
    have=0
    [[ -f "$zip" ]] && have=$(stat -c %s "$zip")
    need=$(( (size * 2 - have) / 1024 ))
    free=$(df -Pk "$NGRAMS_DIR" | awk 'NR==2 {print $4}')
    if (( free < need )); then
      echo "[$lang] not enough space in $NGRAMS_DIR: need ~$((need / 1024 / 1024)) GiB, have $((free / 1024 / 1024)) GiB" >&2
      exit 1
    fi
  fi

  echo "[$lang] downloading $url"
  curl -fL -C - --retry 5 --retry-delay 10 -o "$zip" "$url"

  echo "[$lang] extracting"
  tmp="$NGRAMS_DIR/.extract-$lang"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  unzip_to "$zip" "$tmp"
  # The archives contain a top-level <lang>/ folder; handle a flat layout too.
  if [[ -d "$tmp/$lang" ]]; then
    mv "$tmp/$lang" "$target"
    rm -rf "$tmp"
  else
    mv "$tmp" "$target"
  fi

  rm -f "$zip"
  echo "[$lang] done -> $target"
done
