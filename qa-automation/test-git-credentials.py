#!/usr/bin/env python3
"""Exercise the real helper with stubbed claim discovery and isolated Git config."""
import os
from pathlib import Path
import subprocess
import tempfile

SCRIPT = Path(__file__).resolve().parents[1] / "automation/gitops/components/showroom/files/lab-git-setup.sh"
with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    bin_dir = base / "bin"
    bin_dir.mkdir()
    oc = bin_dir / "oc"
    oc.write_text("#!/usr/bin/env python3\nimport sys\na=sys.argv[-1]\nprint('student' if 'student_username' in a else 'p@ss:/?#%&word' if 'student_password' in a else 'https://gitea.example.test')\n")
    oc.chmod(0o755)
    env = dict(os.environ, HOME=tmp, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=str(base / ".gitconfig"), PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
    def git(*args, **kwargs):
        return subprocess.check_output(["git", *args], cwd=tmp, env=env, text=True, **kwargs).strip()
    git("init", "-q")
    expected = "https://gitea.example.test/student/app.git"
    legacy = "https://student:p@ss:/?#%&word@gitea.example.test/student/app.git"
    git("remote", "add", "origin", legacy)
    git("config", "remote.origin.pushurl", legacy)
    (base / "uncommitted.txt").write_text("keep me")
    subprocess.run(["bash", str(SCRIPT), "--repair-origin", expected], cwd=tmp, env=env, check=True, capture_output=True)
    assert git("remote", "get-url", "origin") == expected
    assert git("remote", "get-url", "--push", "origin") == expected
    assert "p@ss" not in (base / ".git/config").read_text()
    assert (base / "uncommitted.txt").read_text() == "keep me"
    filled = git("credential", "fill", input="url=" + expected + "\n\n")
    assert "password=p@ss:/?#%&word" in filled
    assert (base / ".git-credentials").stat().st_mode & 0o777 == 0o600
    git("config", "remote.origin.url", legacy)
    git("config", "remote.origin.pushurl", "https://other.example.test/app.git")
    before = (base / ".git/config").read_bytes()
    result = subprocess.run(["bash", str(SCRIPT), "--repair-origin", expected], cwd=tmp, env=env, capture_output=True)
    assert result.returncode != 0
    assert (base / ".git/config").read_bytes() == before
    assert b"p@ss" not in result.stdout + result.stderr
    git("credential", "reject", input="url=https://gitea.example.test\n\n")
    assert (base / ".git-credentials").read_text() == ""
print("PASS: reserved characters, credential storage, origin repair/refusal, edit preservation, cleanup")
