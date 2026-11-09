#!/usr/bin/env bash
# Build only: no publication or cluster changes. Requires Node.js, npm, and tar.
set -euo pipefail
OUTPUT_DIR="${1:?Usage: package-rhdh-gitea-plugin.sh OUTPUT_DIR}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
cd "$BUILD_DIR"

# Keep these versions together; test the exported module on the target RHDH.
PLUGIN_VERSION=0.2.23
CLI_VERSION=2.1.2
YARN_VERSION=1.22.22
ARCHIVE="$(npm pack "@backstage/plugin-scaffolder-backend-module-gitea@$PLUGIN_VERSION" --ignore-scripts --silent)"
tar -xzf "$ARCHIVE"
cd package
node <<'JS'
const fs = require('fs');
const p = JSON.parse(fs.readFileSync('package.json', 'utf8'));
// The npm artifact is already compiled. Avoid installing the upstream test/build
// toolchain, and normalize conditional exports for this exporter version.
delete p.devDependencies;
delete p.scripts;
p.exports = {'.': p.main, './package.json': './package.json'};
// Pin the declared direct-dependency baseline and the matching embedded pair.
// Otherwise newer scaffolder-common releases can demand incompatible host APIs.
for (const [name, version] of Object.entries(p.dependencies)) {
  p.dependencies[name] = version.replace(/^\^/, '');
}
p.resolutions = {
  '@backstage/plugin-scaffolder-node': '0.13.5',
  '@backstage/plugin-scaffolder-common': '2.2.1',
};
fs.writeFileSync('package.json', JSON.stringify(p, null, 2) + '\n');
JS
npx --yes "yarn@$YARN_VERSION" install --ignore-scripts --non-interactive
npx --yes "@red-hat-developer-hub/cli@$CLI_VERSION" plugin export --no-build --no-install
cp package.json "$OUTPUT_DIR/source-package.json"
cp yarn.lock "$OUTPUT_DIR/source-yarn.lock"
cd dist-dynamic
npx --yes "yarn@$YARN_VERSION" install --production --ignore-scripts --non-interactive
# This derived package is distributed as an archive, never published to npm.
node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync("package.json"));p.private=true;delete p.publishConfig;fs.writeFileSync("package.json",JSON.stringify(p,null,2)+"\n");'
ARCHIVE="$(npm pack --ignore-scripts --silent)"
cp "$ARCHIVE" "$OUTPUT_DIR/"
cp yarn.lock "$OUTPUT_DIR/dynamic-yarn.lock"
node - "$OUTPUT_DIR/$ARCHIVE" <<'JS'
const fs = require('fs');
const crypto = require('crypto');
const archive = process.argv[2];
const integrity = 'sha512-' + crypto.createHash('sha512').update(fs.readFileSync(archive)).digest('base64');
fs.writeFileSync(archive + '.integrity', integrity + '\n');
console.log('Archive: ' + archive);
console.log('Integrity: ' + integrity);
JS
printf 'Plugin=%s\nRHDH_CLI=%s\nYarn=%s\nNode=%s\n' "$PLUGIN_VERSION" "$CLI_VERSION" "$YARN_VERSION" "$(node --version)" > "$OUTPUT_DIR/build-versions.txt"
