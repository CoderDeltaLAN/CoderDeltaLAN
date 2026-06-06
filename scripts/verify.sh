#!/usr/bin/env bash

set -u

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

ok() {
  printf '[OK] %s\n' "$1"
}

for file in \
  ./README.md \
  ./SECURITY.md \
  ./.gitignore \
  ./assets/cdlan-ai-banner.svg \
  ./assets/cdlan-footer.svg \
  ./assets/cdlan-contact-badge.svg \
  ./assets/cdlan-support-badge.svg \
  ./scripts/verify.sh
do
  test -f "$file" || fail "missing expected file: $file"
done

if test -f ./.github/workflows/verify.yml; then
  expected_count=9
else
  expected_count=8
fi

file_count="$(find . -path './.git' -prune -o -type f -print | wc -l)"
test "$file_count" -eq "$expected_count" || fail "unexpected repository file count: $file_count"
ok "only expected files exist"

asset_count="$(find assets -maxdepth 1 -type f | wc -l)"
test "$asset_count" -eq 4 || fail "unexpected asset count: $asset_count"
ok "asset count is expected"

script_count="$(find scripts -maxdepth 1 -type f | wc -l)"
test "$script_count" -eq 1 || fail "unexpected script count: $script_count"
ok "script count is expected"

if test -d .github/workflows; then
  workflow_count="$(find .github/workflows -maxdepth 1 -type f | wc -l)"
  test "$workflow_count" -le 1 || fail "unexpected workflow count: $workflow_count"
fi
ok "workflow count is safe"

if find . -path './.git' -prune -o -type f -print0 | xargs -0 grep -Il $'\r' | grep -q .; then
  find . -path './.git' -prune -o -type f -print0 | xargs -0 grep -Il $'\r'
  fail "CRLF line endings found"
fi
ok "no CRLF line endings"

if grep -RIn --exclude-dir=.git '[[:blank:]]$' . | grep -q .; then
  grep -RIn --exclude-dir=.git '[[:blank:]]$' .
  fail "trailing whitespace found"
fi
ok "no trailing whitespace"

expected_headings="$(
  cat <<'LIST'
## System map
## What I build
## Operating method
## Core stack
## Public work
## Security boundary
## Contact
## Support
LIST
)"

actual_headings="$(grep -E '^## ' README.md || true)"
test "$actual_headings" = "$expected_headings" || {
  printf '%s\n' "$actual_headings"
  fail "unexpected README section set"
}
ok "README sections are expected"

grep -Fq './assets/cdlan-ai-banner.svg' README.md || fail "README does not reference local AI banner"
grep -Fq './assets/cdlan-footer.svg' README.md || fail "README does not reference local footer"
grep -Fq './assets/cdlan-contact-badge.svg' README.md || fail "README does not reference local contact badge"
grep -Fq './assets/cdlan-support-badge.svg' README.md || fail "README does not reference local support badge"
ok "README references local assets"

if grep -RIn --exclude-dir=.git --exclude='*.md' --exclude='*.svg' --exclude='verify.sh' -E 'ghp_|github_pat_|BEGIN OPENSSH|BEGIN RSA|AKIA[0-9A-Z]{16}|apikey|api_key|password[[:space:]]*=|secret[[:space:]]*=' . | grep -q .; then
  grep -RIn --exclude-dir=.git --exclude='*.md' --exclude='*.svg' --exclude='verify.sh' -E 'ghp_|github_pat_|BEGIN OPENSSH|BEGIN RSA|AKIA[0-9A-Z]{16}|apikey|api_key|password[[:space:]]*=|secret[[:space:]]*=' .
  fail "obvious sensitive pattern found"
fi
ok "no obvious sensitive patterns in executable/config files"

if test -f ./.github/workflows/verify.yml; then
  grep -Fq 'name: Verify' .github/workflows/verify.yml || fail "workflow name is not Verify"
  grep -Fq 'pull_request:' .github/workflows/verify.yml || fail "workflow missing pull_request"
  grep -Fq 'push:' .github/workflows/verify.yml || fail "workflow missing push"
  grep -Fq 'workflow_dispatch:' .github/workflows/verify.yml || fail "workflow missing workflow_dispatch"
  grep -Fq 'contents: read' .github/workflows/verify.yml || fail "workflow does not use read-only contents permission"
  grep -Fq 'bash -n scripts/verify.sh' .github/workflows/verify.yml || fail "workflow missing syntax check"
  grep -Fq 'bash scripts/verify.sh' .github/workflows/verify.yml || fail "workflow missing verify execution"

  if grep -RIn --exclude-dir=.git -E 'contents:[[:space:]]*write|pull-requests:[[:space:]]*write|cron:|git add \.|force-with-lease|curl .*bash' .github/workflows | grep -q .; then
    grep -RIn --exclude-dir=.git -E 'contents:[[:space:]]*write|pull-requests:[[:space:]]*write|cron:|git add \.|force-with-lease|curl .*bash' .github/workflows
    fail "dangerous workflow pattern found"
  fi
  ok "workflow structure is valid"
else
  ok "workflow not present yet"
fi

bash -n scripts/verify.sh || fail "verify script syntax failed"
ok "verify script syntax ok"

printf '[OK] verification passed\n'
