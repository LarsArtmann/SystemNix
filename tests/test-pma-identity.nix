# VM test for git identity propagation (the P5 prevention mechanism).
#
# Validates the chain that prevents "Unknown Author" commits:
#   1. GIT_AUTHOR_NAME/GIT_COMMITTER_NAME env vars produce correct commit identity
#   2. Env vars OVERRIDE bad git config (the PMA daemon mechanism)
#   3. Without env vars and with bad config → "Unknown Author" (the failure mode)
#   4. Pre-commit hook rejects bad identity commits (M5 enforcement)
#
# Does NOT run the PMA daemon (requires AI providers, sops secrets, go-git).
# Tests the BEHAVIORAL CONTRACT: git identity env vars are the prevention mechanism.
# The PMA module translates gitIdentity → env vars; this test validates that chain works.
{ pkgs }:
let
  # Extract just the identity-check portion of the pre-commit hook as a standalone
  # script, so we can test it without the full flake check overhead.
  identityHook = pkgs.writeShellScriptBin "identity-check" ''
    set -euo pipefail
    cd "$(git rev-parse --show-toplevel)"

    author_name="''${GIT_AUTHOR_NAME:-$(git config user.name)}"
    author_email="''${GIT_AUTHOR_EMAIL:-$(git config user.email)}"
    committer_name="''${GIT_COMMITTER_NAME:-$author_name}"

    if [[ "$author_name" == "Unknown Author" ]] || [[ "$author_name" == "unknown" ]] \
       || [[ "$committer_name" == "Unknown Author" ]] || [[ "$committer_name" == "unknown" ]] \
       || [[ "$author_email" == "unknown@"* ]] || [[ -z "$author_name" ]]; then
        echo "REJECTED: author='$author_name' email='$author_email'" >&2
        exit 1
    fi
    echo "ACCEPTED: author='$author_name' email='$author_email'"
    exit 0
  '';
in
{
  name = "pma-identity";

  nodes.machine = {
    environment.systemPackages = [
      pkgs.git
      identityHook
    ];
  };

  testScript = ''
    import subprocess

    def git(repo, *args, env=None):
        cmd = ["git", "-C", repo] + list(args)
        result = machine.succeed(
            " ".join(cmd),
            subprocess.run=True
        )
        return result.strip()

    machine.start()
    machine.wait_for_unit("multi-user.target")

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Test 1: Env vars produce correct commit author
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    machine.succeed("git init /tmp/repo-good")
    machine.succeed("git -C /tmp/repo-good config user.email fallback@example.com")
    machine.succeed("git -C /tmp/repo-good config user.name 'Fallback Name'")
    machine.succeed("echo content > /tmp/repo-good/file.txt")
    machine.succeed("git -C /tmp/repo-good add file.txt")

    # Commit with identity env vars (simulating PMA daemon with gitIdentity set)
    machine.succeed(
        "cd /tmp/repo-good && "
        "GIT_AUTHOR_NAME='Lars Artmann' "
        "GIT_AUTHOR_EMAIL='git@lars.software' "
        "GIT_COMMITTER_NAME='Lars Artmann' "
        "GIT_COMMITTER_EMAIL='git@lars.software' "
        "git commit -m 'test commit'"
    )

    author = machine.succeed("git -C /tmp/repo-good log --format='%an' -1").strip()
    assert author == "Lars Artmann", f"Expected 'Lars Artmann', got '{author}'"

    email = machine.succeed("git -C /tmp/repo-good log --format='%ae' -1").strip()
    assert email == "git@lars.software", f"Expected 'git@lars.software', got '{email}'"

    machine.log("PASS: GIT_AUTHOR_NAME env vars produce correct commit identity")

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Test 2: Env vars OVERRIDE bad git config (the prevention mechanism)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    machine.succeed("git init /tmp/repo-override")
    machine.succeed("git -C /tmp/repo-override config user.name 'Unknown Author'")
    machine.succeed("git -C /tmp/repo-override config user.email 'unknown@example.com'")
    machine.succeed("echo override > /tmp/repo-override/file.txt")
    machine.succeed("git -C /tmp/repo-override add file.txt")

    # Commit with env vars overriding the bad config
    machine.succeed(
        "cd /tmp/repo-override && "
        "GIT_AUTHOR_NAME='Correct Name' "
        "GIT_AUTHOR_EMAIL='correct@example.com' "
        "GIT_COMMITTER_NAME='Correct Name' "
        "GIT_COMMITTER_EMAIL='correct@example.com' "
        "git commit -m 'override test'"
    )

    override_author = machine.succeed("git -C /tmp/repo-override log --format='%an' -1").strip()
    assert override_author == "Correct Name", f"Expected 'Correct Name', got '{override_author}'"

    machine.log("PASS: Env vars override bad git config (PMA prevention works)")

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Test 3: Without env vars, bad config produces "Unknown Author"
    # (This is the failure mode — env vars MUST be set)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    machine.succeed("git init /tmp/repo-bad")
    machine.succeed("git -C /tmp/repo-bad config user.name 'Unknown Author'")
    machine.succeed("git -C /tmp/repo-bad config user.email 'unknown@example.com'")
    machine.succeed("echo bad > /tmp/repo-bad/file.txt")
    machine.succeed("git -C /tmp/repo-bad add file.txt")
    machine.succeed("git -C /tmp/repo-bad commit -m 'bad commit'")

    bad_author = machine.succeed("git -C /tmp/repo-bad log --format='%an' -1").strip()
    assert bad_author == "Unknown Author", f"Expected 'Unknown Author', got '{bad_author}'"

    machine.log("PASS: Bad config without env vars produces 'Unknown Author' (failure mode confirmed)")

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Test 4: Pre-commit identity hook REJECTS "Unknown Author" commits
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    machine.succeed("git init /tmp/repo-hooked")
    machine.succeed("git -C /tmp/repo-hooked config user.name 'Unknown Author'")
    machine.succeed("git -C /tmp/repo-hooked config user.email 'unknown@example.com'")
    machine.succeed("cp ${identityHook}/bin/identity-check /tmp/repo-hooked/.git/hooks/pre-commit")
    machine.succeed("chmod +x /tmp/repo-hooked/.git/hooks/pre-commit")
    machine.succeed("echo test > /tmp/repo-hooked/file.txt")
    machine.succeed("git -C /tmp/repo-hooked add file.txt")

    # Commit WITHOUT env vars → hook should reject it
    result = machine.execute("git -C /tmp/repo-hooked commit -m 'should be rejected' 2>&1 || true")
    assert "REJECTED" in result, f"Expected hook to reject, got: {result}"
    machine.log("PASS: Identity hook rejects 'Unknown Author' commits")

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Test 5: Pre-commit identity hook ACCEPTS good identity via env vars
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    machine.succeed(
        "cd /tmp/repo-hooked && "
        "GIT_AUTHOR_NAME='Good Author' "
        "GIT_AUTHOR_EMAIL='good@example.com' "
        "GIT_COMMITTER_NAME='Good Author' "
        "GIT_COMMITTER_EMAIL='good@example.com' "
        "git commit -m 'accepted commit'"
    )

    good_author = machine.succeed("git -C /tmp/repo-hooked log --format='%an' -1").strip()
    assert good_author == "Good Author", f"Expected 'Good Author', got '{good_author}'"
    machine.log("PASS: Identity hook accepts commits with proper env vars")

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Test 6: Empty author name is rejected by hook
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    machine.succeed("git init /tmp/repo-empty")
    machine.succeed("git -C /tmp/repo-empty config user.email 'test@example.com'")
    # Intentionally do NOT set user.name
    machine.succeed("echo empty > /tmp/repo-empty/file.txt")
    machine.succeed("git -C /tmp/repo-empty add file.txt")
    machine.succeed("cp ${identityHook}/bin/identity-check /tmp/repo-empty/.git/hooks/pre-commit")
    machine.succeed("chmod +x /tmp/repo-empty/.git/hooks/pre-commit")

    result2 = machine.execute("git -C /tmp/repo-empty commit -m 'empty name' 2>&1 || true")
    assert "REJECTED" in result2, f"Expected hook to reject empty name, got: {result2}"
    machine.log("PASS: Identity hook rejects empty author name")
  '';
}
