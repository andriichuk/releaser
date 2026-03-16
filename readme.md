## PHP Project Release, Code Review & Deployment Automation

A small Bash-based toolkit for PHP projects with three scripts: **Releaser** (release flow), **Reviewer** (code review, pre-commit), and **Deployer** (server-side deployment). Requirements and installation are shared; each section below documents one script.

### Requirements

* Bash
* Git
* PHP (local or containerized)
* Composer (local or containerized)

### Installation

**Releaser and Reviewer** (local / CI only):

```shell
composer require andriichuk/releaser --dev
```

**Deployer** (run on the server after deploy): install without `--dev` so the package is available in production (e.g. in your deployment recipe or server `composer install`):

```shell
composer require andriichuk/releaser
```

---

## Releaser

The `releaser` script automates release branch creation, version updates, and post-release branch syncing using simple CLI arguments. The following steps are executed automatically by the script:

**Steps:**

* Switch to the main development branch and pull the latest changes
* Optionally run tests and composer audit to ensure code quality
* Ask for release version and create a release branch
* Optionally update application version in `config/app.php`
* Commit and push the release branch to the remote repository
* Wait for the user to merge the release branch via Pull/Merge Request (merge detected by checking the main branch for the release version in `config/app.php`)
* Create a git tag for the new release version and push it to the remote repository
* Merge the main branch into specified post-release branches to keep them up-to-date

**Usage**

```shell
./vendor/bin/releaser \
  --php-cmd="./vendor/bin/sail php" \
  --composer-cmd="./vendor/bin/sail composer" \
  --main-branch=main \
  --main-dev-branch=develop
```

**Arguments**

| Argument                         | Default                | Description                                                                                                                             |
|----------------------------------|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `--php-cmd`                      | `php`                  | PHP command or wrapper to execute (e.g. `php`, `./vendor/bin/sail php`, `docker exec -T app php`)                                       |
| `--composer-cmd`                 | `composer`             | Composer command (e.g. `composer`, `./vendor/bin/sail composer`, `docker exec -T app composer`)                                         |
| `--git-remote-name`              | `origin`               | Git remote name used for fetch, pull, and push                                                                                          |
| `--main-branch`                  | `main`                 | Primary production branch                                                                                                               |
| `--main-dev-branch`              | `develop`              | Development branch used for ongoing work                                                                                                |
| `--release-branch-prefix`        | `release/`             | Prefix for release branches                                                                                                             |
| `--with-app-version-update`      | `false`                | Whether to update application version in `config/app.php` file. Please note that the file must exists and contain the `'version'` key.  |
| `--post-release-update-branches` | `$main-dev-branch`     | Comma-separated list of branches to update after release (e.g. `develop,stage`, by default value from `--main-dev-branch` will be used) |
| `--with-tests`                   | `true`                 | Whether to run tests before creating a release                                                                                          |
| `--with-composer-audit`          | `true`                 | Whether to run `composer audit` before creating a release                                                                               |
| `--commit-msg-template`          | `Release v{{version}}` | Template for the commit message after making any changes in the release branch (only `{{version}}` placeholder supported)                |

---

## Reviewer (pre-commit hook)

The `reviewer` script runs checks on staged PHP files and the project before commit. It is intended to be used as a Git pre-commit hook or run manually. It requires Laravel Sail (or equivalent) for running commands.

**Steps (each can be toggled via options):**

* **Pint** — Format staged PHP files and re-stage them
* **Dumps check** — Fail if staged PHP files contain `var_dump`, `dump()`, `dd()`, `ddd()`, or `exit;` / `exit(`
* **PHP lint** — Run `php -l` on each staged PHP file
* **PHPStan** — Static analysis on staged PHP files
* **Tests** — Run `sail test --compact`
* **API spec** — Generate OpenAPI spec to `storage/app/private/api.json` (via the project's `vendor/bin/openapi` CLI)
* **Composer audit** — Run `composer audit`

**Usage (Reviewer)**

**1. Run manually with full control over options** — Use this when running the reviewer from the terminal. You can pass any combination of `--php-cmd`, `--composer-cmd`, `--with-tests`, `--with-api-spec`, etc.

```shell
# All checks (defaults)
./vendor/bin/reviewer

# With Laravel Sail
./vendor/bin/reviewer --php-cmd="./vendor/bin/sail php" --composer-cmd="./vendor/bin/sail composer"

# Custom options (e.g. skip tests and API spec)
./vendor/bin/reviewer --with-tests=false --with-api-spec=false
```

**2. Pre-commit hook via symlink** — From the project root, create a symlink so `.git/hooks/pre-commit` points at the vendor script. The hook always runs the script with its default options; no wrapper file to maintain.

```shell
ln -sf ../../vendor/bin/reviewer .git/hooks/pre-commit
```

**3. Pre-commit hook via wrapper file (copy)** — Use this when you want the hook to run the reviewer with custom options (e.g. `--with-tests=false`). Create `.git/hooks/pre-commit` with a shebang and an `exec` line so the process is replaced and Git receives the script’s exit code; then make the file executable with `chmod +x`.

```shell
echo '#!/bin/sh' > .git/hooks/pre-commit
echo 'exec ./vendor/bin/reviewer --with-tests=false' >> .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

To skip the reviewer on a single commit, use `git commit --no-verify`.

**Arguments (Reviewer)**

All options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults are `true` unless noted.

| Argument                   | Default | Description                                                                 |
|----------------------------|---------|-----------------------------------------------------------------------------|
| `--php-cmd`                | `php`   | PHP command or wrapper (e.g. `php`, `./vendor/bin/sail php`, `docker exec -T app php`) |
| `--composer-cmd`           | `composer` | Composer command (e.g. `composer`, `./vendor/bin/sail composer`)        |
| `--with-pint`              | `true`  | Run Pint on staged PHP files and re-stage                                   |
| `--with-dumps-check`       | `true`  | Check staged PHP files for dump/exit calls      |
| `--with-php-lint`          | `true`  | Run `php -l` on staged PHP files                 |
| `--with-phpstan`           | `true`  | Run PHPStan on staged PHP files                  |
| `--with-tests`             | `true`  | Run test suite                                  |
| `--with-composer-audit`    | `true`  | Run `composer audit`                             |
| `--with-api-spec`          | `true`  | Generate OpenAPI spec to `storage/app/private/api.json` (via the project's `vendor/bin/openapi` CLI) |
| `--full`                  | `false` | Run Pint, dumps check, PHP lint, and PHPStan on the whole project (excl. vendor/node_modules) instead of staged files only; Pint is not re-staged |

**Examples (Reviewer)**

```shell
# Quick commit: only Pint and dumps check
./vendor/bin/reviewer --with-php-lint=false --with-phpstan=false --with-tests=false --with-composer-audit=false --with-api-spec=false

# Skip tests and Composer audit
./vendor/bin/reviewer --with-tests=false --with-composer-audit=false

# Run file-based checks on the whole project (not just staged)
./vendor/bin/reviewer --full=true
```

---

## Deployer

The `deployer` script runs common Laravel deployment steps on the server: optionally put the app in maintenance mode, clear and rebuild caches, optimize, run migrations, create the storage link, bring the app out of maintenance, run Filament optimize, and terminate Horizon. Each step can be toggled via options. Use it in your deployment pipeline or run it manually after deploying code.

**Steps (each can be toggled via options):**

* **Maintenance** — `artisan down` before deploy and `artisan up` after (single option, default off)
* **Clear caches** — `optimize:clear` (config, route, view, cache, compiled, events)
* **Caching** — `view:cache`, `config:cache`, `route:cache` (optional), `event:cache` (optional)
* **Filament optimize** — `filament:optimize` (disable if the app does not use Filament)
* **Optimize** — `optimize`
* **Livewire assets** — `vendor:publish --force --tag=livewire:assets` (optional, default off)
* **npm build** — `npm run build` for production frontend assets (optional, default off)
* **API spec** — Generate OpenAPI spec to `storage/app/private/api.json` via the project's `vendor/bin/openapi` CLI (optional, default off)
* **Migrations** — `migrate --force`
* **Storage link** — `storage:link` (disable if the link already exists)
* **Horizon terminate** — `horizon:terminate` (disable if the app does not use Horizon)

**Order:** Build steps (caches, optimize, Livewire, npm build, API spec) run *before* bringing the app up so new code and assets are in place before traffic hits. Run the script from the **project root** (directory containing `artisan`).

**Usage (Deployer)**

```shell
# Run all steps (defaults)
./vendor/bin/deployer

# Custom PHP binary (e.g. on server with multiple PHP versions)
./vendor/bin/deployer --php=php8.4

# App without Horizon or Filament
./vendor/bin/deployer --with-horizon-terminate=false --with-filament-optimize=false

# Skip storage link (already created)
./vendor/bin/deployer --with-storage-link=false

# Put app in maintenance during deploy (down at start, up at end)
./vendor/bin/deployer --with-maintenance=true
```

**Arguments (Deployer)**

All boolean options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults are `true` unless noted.

| Argument                      | Default   | Description                                                                 |
|-------------------------------|-----------|-----------------------------------------------------------------------------|
| `--php`                       | `php`     | PHP binary or wrapper (e.g. `php`, `php8.4`, `./vendor/bin/sail php`)      |
| `--with-maintenance`          | `true`    | Run `artisan down` before deploy and `artisan up` after                     |
| `--with-migrate`              | `true`    | Run `artisan migrate --force`                                               |
| `--with-storage-link`         | `true`    | Run `artisan storage:link`                                                  |
| `--with-filament-optimize`    | `true`    | Run `artisan filament:optimize`                                             |
| `--with-horizon-terminate`    | `false`   | Run `artisan horizon:terminate`                                             |
| `--with-api-spec`             | `false`   | Generate OpenAPI spec to `storage/app/private/api.json` (runs the project's `vendor/bin/openapi` binary; your project must have an OpenAPI generator that provides this CLI) |
| `--with-livewire-assets`      | `false`   | Publish Livewire static assets (`vendor:publish --force --tag=livewire:assets`) |
| `--with-npm-build`            | `false`   | Run `npm run build` for production frontend assets (Vite etc.)                  |
| `--with-route-cache`          | `true`    | Run `route:cache` (set `false` if your routes use closures)              |
| `--with-event-cache`          | `true`    | Run `event:cache`                                                         |

**Caveats:** `route:cache` fails when routes are defined as closures; use `--with-route-cache=false`. On repeat deploys, use `--with-storage-link=false` if the storage symlink already exists.

**Examples (Deployer)**

```shell
# Full deploy with default PHP
./vendor/bin/deployer

# PHP 8.4, with Horizon termination
./vendor/bin/deployer --php=php8.4 --with-horizon-terminate=true

# Minimal: only caches and optimize, no migrate/link/horizon
./vendor/bin/deployer --with-migrate=false --with-storage-link=false --with-horizon-terminate=false

# Without maintenance-mode
./vendor/bin/deployer --with-maintenance=false

# Build frontend assets during deploy (npm run build)
./vendor/bin/deployer --with-npm-build=true
```

### TODO

* Allow to merge without running PHP or Composer commands
* Improve the logic of detecting that MR is merged (e.g. check git tags on the main branch)
* Release notes generation based on commit messages
* Main branch name detection
* Latest version detection based on git tags or `config/app.php` file
* Linters (PHPStan, Dumps checker, Pint, Native PHP Linter, OpenAPI doc validation, JS production bundle generation, etc.)