#!/usr/bin/env bash
# Instructor QA in Showroom. Uses a temporary clone; never edits student work.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
oc -n gitea get configmap lab-gitea -o json > "$work/gitea.json"
oc -n lightwell-repo get configmap lab-lightwell-repo -o json > "$work/nexus.json"
repo=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["data"]["lightwell_dependencies_repo_url"])' "$work/gitea.json")
branch=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["data"]["lightwell_dependencies_repo_revision"])' "$work/gitea.json")
git clone --branch "$branch" "$repo" "$work/starter"
cd "$work/starter"
python3 - "$work/nexus.json" <<'PYTHON'
import json,sys
from pathlib import Path
config=json.load(open(sys.argv[1]))['data']
p=Path('settings.xml')
s=p.read_text()
for channel in ['validated','remediated']:
    s=s.replace('REPLACE_ME_'+channel.upper()+'_URL', config['nexus_url'].rstrip('/')+'/repository/'+config['channel_'+channel]+'/')
p.write_text(s)
assert len(Path('WORKSHOP_REVISION').read_text().strip()) == 40
PYTHON
# Match the advisory actually provisioned for Nexus, not a separately maintained sample.
oc -n lightwell-repo get configmap lightwell-repo-seed -o jsonpath='{.data.LW-DEMO-0002\.json}' > "$work/cluster-osv.json"
python3 - "$work/cluster-osv.json" <<'PYTHON'
import json,sys
assert json.load(open(sys.argv[1])) == json.load(open('advisories/LW-DEMO-0002.json'))
PYTHON
for channel in validated remediated; do
  if [[ "$channel" == remediated ]]; then
    python3 - <<'PYTHON'
import json
from pathlib import Path
record=json.loads(Path('advisories/LW-DEMO-0002.json').read_text())
versions=[event['fixed'] for a in record['affected'] if a['package']['name']=='org.apache.commons:commons-lang3' for range_ in a['ranges'] for event in range_['events'] if 'fixed' in event]
assert versions == ['3.14.0.rhlw-00001']
p=Path('pom.xml'); p.write_text(p.read_text().replace('<commons.lang3.version>3.14.0</commons.lang3.version>', '<commons.lang3.version>'+versions[0]+'</commons.lang3.version>'))
PYTHON
  fi
  log="$work/$channel.log"
  mvn -B -s settings.xml -f pom.xml -Dmaven.repo.local="$work/m2-$channel" \
    -P"lightwell-$channel" org.apache.maven.plugins:maven-dependency-plugin:3.7.0:resolve \
    org.apache.maven.plugins:maven-dependency-plugin:3.7.0:tree > "$log" 2>&1 || { cat "$log"; exit 1; }
  python3 - "$log" "$channel" "$work/nexus.json" <<'PYTHON'
import json,sys
text=open(sys.argv[1]).read()
channel=sys.argv[2]
config=json.load(open(sys.argv[3]))['data']
version='3.14.0' if channel=='validated' else '3.14.0.rhlw-00001'
assert 'org.apache.commons:commons-lang3:jar:'+version+':compile' in text
url=config['nexus_url'].rstrip('/')+'/repository/'+config['channel_'+channel]+'/'
assert any('Downloaded from lightwell-java-'+channel+':' in line and url in line and 'commons-lang3-'+version+'.jar' in line for line in text.splitlines()), 'No successful Commons Lang download from the expected Nexus channel'
PYTHON
  echo "PASS: $channel version and Nexus download"
done
