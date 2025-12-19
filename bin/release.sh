#!/usr/bin/env bash

############################################
# Defaults (can be overridden by CLI args)
############################################
PHP_PATH="./vendor/bin/sail php"
REMOTE="origin"
MAIN_BRANCH="main"
MAIN_DEV_BRANCH="develop"
CONFIG_FILE="./config/app.php"
BRANCH_PREFIX="release/"

############################################
# CLI argument parsing
############################################
for arg in "$@"; do
  case "$arg" in
    --php-path=*)
      PHP_PATH="${arg#*=}"
      ;;
    --remote-name=*)
      REMOTE="${arg#*=}"
      ;;
    --main-branch=*)
      MAIN_BRANCH="${arg#*=}"
      ;;
    --main-dev-branch=*)
      MAIN_DEV_BRANCH="${arg#*=}"
      ;;
    --release-branch-prefix=*)
      BRANCH_PREFIX="${arg#*=}"
      ;;
    --config-file=*)
      CONFIG_FILE="${arg#*=}"
      ;;
    *)
      echo -e "${RED}Unknown argument: $arg${RESET}"
      exit 1
      ;;
  esac
done

# helper colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# helper: print and run, returning status
run() {
  echo -e "${YELLOW}+ $*${RESET}"
  eval "$@"
  return $?
}

fail() {
  echo -e "${RED}✖ $*${RESET}"
  exit 1
}

info() {
  echo -e "${GREEN}→ $*${RESET}"
}

if eval "${PHP_PATH} --version" >/dev/null 2>&1; then
  PHP_VERSION_OUTPUT=$(eval "${PHP_PATH} --version" 2>/dev/null | head -n1)
  PHP_VERSION=$(echo "${PHP_VERSION_OUTPUT}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [ -n "${PHP_VERSION}" ]; then
    info "Using PHP command: ${PHP_PATH} (version ${PHP_VERSION})"
  else
    info "Using PHP command: ${PHP_PATH}"
  fi
else
  fail "PHP executable or wrapper not found or not executable: ${PHP_PATH}. Export PHP_PATH to point to your sail/php script if necessary."
fi

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Not inside a git repository."
fi

# ensure working tree clean
if ! git diff --quiet || ! git diff --staged --quiet; then
  echo -e "${YELLOW}Warning: You have uncommitted changes. It's recommended to start from a clean working tree.${RESET}"
  read -p "Continue anyway? [y/N]: " cont
  case "$cont" in
    [Yy]*) ;;
    *) fail "Aborting."; ;;
  esac
fi

# 1. checkout develop and pull latest
info "Switching to ${MAIN_DEV_BRANCH} and pulling latest..."
if git rev-parse --verify "$MAIN_DEV_BRANCH" >/dev/null 2>&1; then
  run "git checkout ${MAIN_DEV_BRANCH}" || fail "Cannot switch to ${MAIN_DEV_BRANCH}"
else
  run "git switch -c ${MAIN_DEV_BRANCH}" || run "git checkout -b ${MAIN_DEV_BRANCH}" || fail "Failed to create/switch to ${MAIN_DEV_BRANCH}"
fi
run "git pull ${REMOTE} ${MAIN_DEV_BRANCH}" || fail "Failed to pull ${MAIN_DEV_BRANCH} from ${REMOTE}"

# 2. Linting steps (fail on any error)
info "Running lint & tests..."

info "Running phpstan..."
run "${PHP_PATH} ./vendor/bin/phpstan analyse" || fail "phpstan failed"

info "Generating API spec (openapi) to ensure schema validity..."
run "${PHP_PATH} php ./vendor/bin/openapi app -o storage/app/private/api.json -f json" || fail "OpenAPI generation failed"

info "Running tests"
run "${PHP_PATH} test --compact" || fail "Tests failed"

info "Checking composer dependencies (composer audit)"
run "${PHP_PATH} composer audit" || fail "Composer audit reported issues"

info "Searching for debug dumps in PHP files..."
if git grep -Eiw "var_dump|dump\(|dd\(|ddd\(|exit;|exit\(" -- '*.php' >/tmp/release_grep_result 2>/dev/null; then
  echo -e "${RED}Found debug/dump/exit occurrences:${RESET}"
  sed -n '1,200p' /tmp/release_grep_result
  rm -f /tmp/release_grep_result
  fail "Remove debug calls (var_dump, dump, dd, ddd, exit) before release."
else
  rm -f /tmp/release_grep_result 2>/dev/null || true
  info "No debug/dump/exit occurrences found."
fi

info "Formatting code with pint..."
run "${PHP_PATH} php ./vendor/bin/pint" || fail "Code formatting failed"

echo
read -p "Enter release version (eg. 1.0.0): " VERSION
VERSION="${VERSION// /}" # trim spaces
if [ -z "$VERSION" ]; then
  fail "No version provided, aborting."
fi

info "Fetching tags from ${REMOTE}..."
run "git fetch --tags ${REMOTE}" || fail "Failed to fetch tags"

if git rev-parse "refs/tags/${VERSION}" >/dev/null 2>&1; then
  fail "Tag '${VERSION}' already exists locally."
fi
if git ls-remote --tags "${REMOTE}" | grep -E "refs/tags/${VERSION}$" >/dev/null 2>&1; then
  fail "Tag '${VERSION}' already exists on remote ${REMOTE}."
fi

RELEASE_BRANCH="${BRANCH_PREFIX}${VERSION}"
info "Creating branch ${RELEASE_BRANCH}..."
run "git checkout -b ${RELEASE_BRANCH}" || fail "Failed to create branch ${RELEASE_BRANCH}"

info "Updating version in ${CONFIG_FILE} to ${VERSION}..."
if [ ! -f "${CONFIG_FILE}" ]; then
  fail "Config file '${CONFIG_FILE}' not found."
fi

# Use sed -E with -i.bak for portability (works on GNU and BSD sed)
# This replaces 'version' => 'old' or "version" => "old"
SED_PATTERN="s/(['\"]version['\"]\\s*=>\\s*['\"][^'\"]*['\"])\\s*/\\1/"

# We will perform targeted replacement: replace the value after 'version' => '...'
# The sed below uses a capture group for prefix and suffix and inserts new version preserving quote style
# It will create a .bak (portable). We'll remove the .bak after success.
run "sed -E -i.bak \"s/(['\\\"]version['\\\"]\\s*=>\\s*['\\\"])[^'\\\"]+(['\\\"])/\\1${VERSION}\\2/\" \"${CONFIG_FILE}\"" || {
  # restore backup if something went wrong
  [ -f "${CONFIG_FILE}.bak" ] && mv "${CONFIG_FILE}.bak" "${CONFIG_FILE}"
  fail "Failed to update ${CONFIG_FILE}"
}
# remove backup
rm -f "${CONFIG_FILE}.bak"

info "Staging ${CONFIG_FILE}..."
run "git add \"${CONFIG_FILE}\"" || fail "git add failed"

COMMIT_MSG="Release ${VERSION}"
info "Committing changes: ${COMMIT_MSG}"
run "git commit -m \"${COMMIT_MSG}\"" || fail "git commit failed"

info "Pushing branch ${RELEASE_BRANCH} to ${REMOTE}..."
run "git push -u ${REMOTE} ${RELEASE_BRANCH}" || fail "git push failed"

echo
info "When you finish creating and merging the Merge/Pull Request, press any key to continue..."
read -n1 -s -r -p "Press any key when merged (or Ctrl+C to abort)..." ; echo

while true; do
  info "Fetching ${MAIN_BRANCH} from ${REMOTE}..."
  run "git fetch ${REMOTE} ${MAIN_BRANCH}" || fail "Failed to fetch ${MAIN_BRANCH}"

  if git rev-parse --verify "${MAIN_BRANCH}" >/dev/null 2>&1; then
    if git switch "${MAIN_BRANCH}" >/dev/null 2>&1; then
      :
    else
      git checkout "${MAIN_BRANCH}" >/dev/null 2>&1 || fail "Failed to switch to ${MAIN_BRANCH}"
    fi
  else
    fail "Main branch ${MAIN_BRANCH} does not exist locally."
  fi

  run "git pull ${REMOTE} ${MAIN_BRANCH}" || fail "Failed to pull ${MAIN_BRANCH}"

  if [ ! -f "${CONFIG_FILE}" ]; then
    fail "Config file ${CONFIG_FILE} not found on ${MAIN_BRANCH}."
  fi

  if grep -E "(['\"]version['\"]\\s*=>\\s*['\"])${VERSION}(['\"])" "${CONFIG_FILE}" >/dev/null 2>&1; then
    info "Detected version ${VERSION} in ${CONFIG_FILE} on branch ${MAIN_BRANCH}."
    break
  else
    echo
    echo -e "${YELLOW}It seems ${CONFIG_FILE} on ${MAIN_BRANCH} does not contain version ${VERSION} yet.${RESET}"
    read -p "Have you merged the MR? Press any key to re-check or Ctrl+C to abort..." -n1 -s ; echo
  fi
done

info "Creating annotated tag '${VERSION}' on ${MAIN_BRANCH} (this will open your git editor for message)..."

run "git switch ${MAIN_BRANCH}" || fail "Cannot switch to ${MAIN_BRANCH}"
run "git pull ${REMOTE} ${MAIN_BRANCH}" || fail "Failed to pull ${MAIN_BRANCH}"

run "git tag -a \"${VERSION}\"" || fail "Failed to create tag ${VERSION}"

info "Pushing tag '${VERSION}' to ${REMOTE}..."
run "git push ${REMOTE} \"refs/tags/${VERSION}\"" || fail "Failed to push tag ${VERSION}"

info "Updating ${MAIN_DEV_BRANCH} from ${MAIN_BRANCH}..."

run "git fetch ${REMOTE} ${MAIN_DEV_BRANCH} ${MAIN_BRANCH}" || fail "Failed to fetch branches"

if git rev-parse --verify "${MAIN_DEV_BRANCH}" >/dev/null 2>&1; then
  run "git switch ${MAIN_DEV_BRANCH}" || run "git checkout ${MAIN_DEV_BRANCH}" || fail "Cannot switch to ${MAIN_DEV_BRANCH}"
  run "git pull ${REMOTE} ${MAIN_DEV_BRANCH}" || fail "Failed to pull ${MAIN_DEV_BRANCH}"
fi

run "git switch ${MAIN_BRANCH}" || run "git checkout ${MAIN_BRANCH}" || fail "Cannot switch to ${MAIN_BRANCH}"
run "git pull ${REMOTE} ${MAIN_BRANCH}" || fail "Failed to pull ${MAIN_BRANCH}"

run "git switch ${MAIN_DEV_BRANCH}" || run "git checkout ${MAIN_DEV_BRANCH}" || fail "Cannot switch to ${MAIN_DEV_BRANCH}"
run "git merge origin/${MAIN_BRANCH}" || fail "Failed to merge ${MAIN_BRANCH} into ${MAIN_DEV_BRANCH}"
run "git push ${REMOTE} ${MAIN_DEV_BRANCH}" || fail "Failed to push ${MAIN_DEV_BRANCH}"

echo
echo -e "${GREEN}Release ${VERSION} completed successfully! 🎉${RESET}"
echo -e "${GREEN}Tag '${VERSION}' pushed. ${RESET}"
