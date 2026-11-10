#!/usr/bin/env python3
"""Package a clearly marked simulation fixture; never claim a security backport.

Class files and license notices stay byte-for-byte upstream. Only package identity
metadata changes so the seeded sample advisory can be compared to Syft inventory.
"""
import argparse
from pathlib import Path
import re
import zipfile

VERSION = "3.14.0.rhlw-00001"
MAVEN = "META-INF/maven/org.apache.commons/commons-lang3/"

def build(source, destination, pom):
    if Path(source).resolve() == Path(destination).resolve():
        raise ValueError("Keep the validated upstream JAR unchanged")
    with zipfile.ZipFile(source) as jar:
        names = jar.namelist()
        required = {MAVEN + "pom.properties", MAVEN + "pom.xml", "META-INF/MANIFEST.MF"}
        if not required.issubset(names):
            raise ValueError("Expected Commons Lang Maven and manifest metadata")
        if any(re.match(r"META-INF/[^/]+\.(SF|RSA|DSA|EC)$", n, re.I) for n in names):
            raise ValueError("Refuse to modify a signed upstream JAR")
        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as out:
            for info in jar.infolist():
                data = jar.read(info.filename)
                if info.filename == MAVEN + "pom.properties":
                    data = ("# Workshop simulation; upstream classes unchanged\n"
                            "groupId=org.apache.commons\nartifactId=commons-lang3\n"
                            f"version={VERSION}\n").encode()
                elif info.filename == MAVEN + "pom.xml":
                    data = Path(pom).read_bytes()
                elif info.filename == "META-INF/MANIFEST.MF":
                    # Unfold manifest continuation lines before changing identity.
                    text = data.decode().replace("\r\n", "\n").replace("\n ", "")
                    for key in ("Implementation-Version", "Specification-Version", "Bundle-Version"):
                        text = re.sub(r"(?m)^" + key + r":.*$", key + ": " + VERSION, text)
                    # OSGi Export-Package also carries the upstream package version.
                    text = text.replace('version="3.14.0"', 'version="' + VERSION + '"')
                    lines = text.rstrip("\n").split("\n") + ["Lightwell-Workshop-Simulation: true"]
                    # JAR manifests wrap at 72 bytes; upstream manifest is ASCII.
                    wrapped = []
                    for line in lines:
                        while len(line.encode()) > 70:
                            wrapped.append(line[:70]); line = " " + line[70:]
                        wrapped.append(line)
                    data = ("\r\n".join(wrapped) + "\r\n\r\n").encode()
                out.writestr(info, data)
            out.writestr("META-INF/lightwell-workshop-simulation.txt",
                         "WORKSHOP SIMULATION ONLY. Upstream 3.14.0 class files are unchanged. "
                         "This is not a Red Hat build or a security backport. "
                         "LW-DEMO-0002 is a synthetic advisory.\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument("pom")
    args = parser.parse_args()
    build(args.source, args.destination, args.pom)
