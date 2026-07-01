#!/usr/bin/env bash
# verify_governance_integrity.sh — deployed by install.sh to
# .githooks/verify_governance_integrity.sh, invoked by both CI
# (.github/workflows/gate.yml) and the bats test suite (test_helper.bash's
# run_ci_integrity_check). Single source of truth for the governance-file
# presence + content-hash check — extracted out of ci-gate.yml specifically
# so CI and the test suite can never drift out of sync with each other again
# (a prior audit found the hand-duplicated copy had silently gone stale).
set -euo pipefail

test -f .githooks/gate.sh   || { echo "::error::.githooks/gate.sh missing — governance stripped"; exit 1; }
test -f .claude/gate_state.json || { echo "::error::.claude/gate_state.json missing"; exit 1; }
test -f .claude/gate_integrity.sha256 || { echo "::error::.claude/gate_integrity.sha256 missing — integrity pin stripped"; exit 1; }

# Content-hash check, not just presence: a PR can otherwise weaken gate.sh
# and still pass CI as long as the file exists. This is the actual security
# boundary — .claude/gate_integrity.sha256 must be blocked from casual agent
# edits (see the trust-root deny-list in .claude/settings.json) and ideally
# covered by CODEOWNERS + branch protection so only a human-reviewed PR can
# move the pinned hash.
ACTUAL_HASH=$(sha256sum .githooks/gate.sh 2>/dev/null | awk '{print $1}' || shasum -a 256 .githooks/gate.sh 2>/dev/null | awk '{print $1}')
EXPECTED_HASH=$(awk '{print $1}' .claude/gate_integrity.sha256)
if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
    echo "::error::Deployed gate.sh content does not match the pinned integrity hash." >&2
    echo "::error::expected=${EXPECTED_HASH} actual=${ACTUAL_HASH}" >&2
    echo "::error::If this change is legitimate, re-run install.sh --upgrade to regenerate the pin, then commit both files together under human review." >&2
    exit 1
fi
echo "Governance files present and integrity-verified."
