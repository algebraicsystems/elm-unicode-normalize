#!/bin/sh

set -e

pnpm exec -- parcel build benchmarks/index.js >/dev/null

echo "Compiled (uncompressed) bundle size is $(cat dist/index.js | wc -c) bytes"
echo "Compressed bundle size is $(cat dist/index.js | gzip | wc -c) bytes"
