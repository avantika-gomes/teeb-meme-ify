#!/bin/sh
# Xcode Cloud runs this right after cloning. Config/Secrets.xcconfig is gitignored, so recreate it
# from the OPENAI_API_KEY secret set on the workflow (Environment → Environment Variables, Secret).
set -eu

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "error: OPENAI_API_KEY is not set. Add it as a secret environment variable on this Xcode Cloud workflow." >&2
  exit 1
fi

printf 'OPENAI_API_KEY = %s\n' "$OPENAI_API_KEY" > "$CI_PRIMARY_REPOSITORY_PATH/Config/Secrets.xcconfig"
echo "Wrote Config/Secrets.xcconfig"
