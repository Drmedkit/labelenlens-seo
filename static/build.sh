#!/bin/bash
cd "$(dirname "$0")"
npx tailwindcss@3 -i css/input.css -o css/style.css --minify
echo "✅ CSS built: $(wc -c < css/style.css) bytes"
