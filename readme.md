## PHP project release tooling

Bash helpers for PHP and Laravel: automate releases, guard commits, run deploy steps, and bootstrap local Sail environments.

* **[Releaser](#releaser)** — release branches, versioning, tags, and post-release branch sync.
* **[Reviewer](#reviewer)** — pre-commit checks (Pint, PHPStan, tests, audit, and more).
* **[Deployer](#deployer)** — Laravel 11+ server deploy (caches, optimize, migrate, optional npm build).
* **[Installer](#installer)** — local Laravel + Sail setup (env, Composer in Docker, Sail, Artisan, hosts, OpenAPI, pre-commit hook).
* **[Spark](#spark)** — start a new feature: sync dev branch, install deps, run migrate/cache clear, create feature branch, optional `npm run dev`.
* **[Rescue](#rescue)** — same as Spark, but creates a **bugfix** branch (default prefix `bugfix/`), optional `npm run dev`.

### Installation

For local release automation (`releaser`), pre-commit checks (`reviewer`), local Sail bootstrap (`installer`), and branch bootstrap (`spark`, `rescue`), install as a dev dependency:

```shell
composer require andriichuk/releaser --dev
```

If you use [Deployer](#deployer) on servers or in deployment pipelines where Composer omits dev dependencies (e.g. `composer install --no-dev`), require the package **without** `--dev` so `vendor/bin/deployer` is available:

```shell
composer require andriichuk/releaser
```

A small Bash-based toolkit for PHP projects with six scripts: **Releaser** (release flow), **Reviewer** (code review, pre-commit), **Deployer** (server-side deployment), **Installer** (local Laravel + Sail bootstrap), **Spark** (feature-start flow), and **Rescue** (bugfix-start flow). Requirements and installation are shared; each section below documents one script.

### Requirements

* Bash
* Git
* PHP (local or containerized)
* Composer (local or containerized)

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

#### Usage

```shell
./vendor/bin/releaser \
  --php-cmd="./vendor/bin/sail php" \
  --composer-cmd="./vendor/bin/sail composer" \
  --main-branch=main \
  --main-dev-branch=develop
```

Add to your project’s `composer.json` under `scripts` so you can run `composer release`:

```json
{
    "scripts": {
        "release": "vendor/bin/releaser --main-branch=main --main-dev-branch=develop"
    }
}
```

With Laravel Sail, use a script that passes the same flags as in the shell example above:

```json
{
    "scripts": {
        "release": "vendor/bin/releaser --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer' --main-branch=main --main-dev-branch=develop"
    }
}
```

#### Arguments

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

## Reviewer

The `reviewer` script runs checks on staged PHP files and the project before commit. It is intended to be used as a Git pre-commit hook or run manually. It requires Laravel Sail (or equivalent) for running commands.

**Steps (each can be toggled via options):**

* **Pint** — Format staged PHP files and re-stage them (whole-project mode with `--full` does not re-stage)
* **Dumps check** — Fail if staged PHP files contain `var_dump`, `dump()`, `dd()`, `ddd()`, or `exit;` / `exit(`
* **PHP lint** — Run `php -l` on each staged PHP file
* **PHPStan** — Static analysis on staged PHP files
* **Tests** — Run `php artisan test --compact` (with colors when supported)
* **API spec** — Generate OpenAPI spec to `storage/app/private/api.json` (via the project's `vendor/bin/openapi` CLI)
* **Composer audit** — Run `composer audit`
* **npm audit** — Optional; runs when `package.json` exists and `--with-npm-audit=true`

#### Usage

**1. Run manually** — You can pass any combination of `--php-cmd`, `--composer-cmd`, `--npm-cmd`, `--with-tests`, `--with-api-spec`, `--full`, etc.

```shell
# All checks (defaults)
./vendor/bin/reviewer

# With Laravel Sail
./vendor/bin/reviewer --php-cmd="./vendor/bin/sail php" --composer-cmd="./vendor/bin/sail composer"

# Custom options (e.g. skip tests and API spec)
./vendor/bin/reviewer --with-tests=false --with-api-spec=false
```

Add to your project’s `composer.json` under `scripts` so you can run `composer review`:

```json
{
    "scripts": {
        "review": "vendor/bin/reviewer"
    }
}
```

With Laravel Sail:

```json
{
    "scripts": {
        "review": "vendor/bin/reviewer --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer'"
    }
}
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

#### Arguments

All options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults are `true` unless noted.

| Argument                   | Default | Description                                                                 |
|----------------------------|---------|-----------------------------------------------------------------------------|
| `--php-cmd`                | `php`   | PHP command or wrapper (e.g. `php`, `./vendor/bin/sail php`, `docker exec -T app php`) |
| `--composer-cmd`           | `composer` | Composer command (e.g. `composer`, `./vendor/bin/sail composer`)        |
| `--npm-cmd`                | `npm`   | npm command (e.g. `npm`, `pnpm`)                                            |
| `--with-pint`              | `true`  | Run Pint on staged PHP files and re-stage                                   |
| `--with-dumps-check`       | `true`  | Check staged PHP files for dump/exit calls      |
| `--with-php-lint`          | `true`  | Run `php -l` on staged PHP files                 |
| `--with-phpstan`           | `true`  | Run PHPStan on staged PHP files                  |
| `--with-tests`             | `true`  | Run test suite                                  |
| `--with-composer-audit`    | `true`  | Run `composer audit`                             |
| `--with-npm-audit`         | `false` | Run `npm audit` when `package.json` exists      |
| `--with-api-spec`          | `true`  | Generate OpenAPI spec to `storage/app/private/api.json` (via the project's `vendor/bin/openapi` CLI) |
| `--full`                  | `false` | Run Pint, dumps check, PHP lint, and PHPStan on the whole project (excl. vendor/node_modules) instead of staged files only; Pint is not re-staged |

#### Examples

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

The `deployer` script runs common Laravel deployment steps on the server: optionally put the app in maintenance mode, clear and rebuild caches, optimize, optionally run `npm run build`, run migrations, create the storage link, bring the app out of maintenance, run Filament optimize, and terminate Horizon. Each step can be toggled via options. Use it in your deployment pipeline or run it manually after deploying code.

**Steps (each can be toggled via options):**

* **Maintenance** — `artisan down` before deploy and `artisan up` after (single option; default on)
* **Clear caches** — `optimize:clear` (config, route, view, cache, compiled, events)
* **Filament optimize** — `filament:optimize` (disable if the app does not use Filament)
* **Optimize** — `optimize` (config, events, routes, views)
* **npm build** — `npm run build` for production frontend assets (optional, default off)
* **Livewire assets** — `vendor:publish --force --tag=livewire:assets` (optional, default off)
* **API spec** — Generate OpenAPI spec to `storage/app/private/api.json` via the project's `vendor/bin/openapi` CLI (optional, default off)
* **Migrations** — `migrate --force`
* **Storage link** — `storage:link --force` (recreates symlink if needed; safe on repeat deploys)
* **Horizon terminate** — `horizon:terminate` (disable if the app does not use Horizon)

**Order:** Build steps (caches, Filament optimize, npm, optimize, Livewire, API spec) run *before* bringing the app up so new code and assets are in place before traffic hits. Run the script from the **project root** (directory containing `artisan`).

#### Usage

```shell
# Run all steps (defaults)
./vendor/bin/deployer

# Custom PHP binary (e.g. on server with multiple PHP versions)
./vendor/bin/deployer --php=php8.4

# App without Horizon or Filament
./vendor/bin/deployer --with-horizon-terminate=false --with-filament-optimize=false

# Skip storage link (e.g. managed outside this script)
./vendor/bin/deployer --with-storage-link=false

# Put app in maintenance during deploy (down at start, up at end)
./vendor/bin/deployer --with-maintenance=true
```

Add to your project’s `composer.json` under `scripts` so you can run `composer deploy`:

```json
{
    "scripts": {
        "deploy": "vendor/bin/deployer"
    }
}
```

If deploy runs through Sail or a specific PHP binary:

```json
{
    "scripts": {
        "deploy": "vendor/bin/deployer --php='./vendor/bin/sail php'"
    }
}
```

#### Arguments

All boolean options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults are `true` unless noted.

| Argument                      | Default   | Description                                                                 |
|-------------------------------|-----------|-----------------------------------------------------------------------------|
| `--php`                       | `php`     | PHP binary or wrapper (e.g. `php`, `php8.4`, `./vendor/bin/sail php`)      |
| `--with-maintenance`          | `true`    | Run `artisan down` before deploy and `artisan up` after                     |
| `--with-migrate`              | `true`    | Run `artisan migrate --force`                                               |
| `--with-storage-link`         | `true`    | Run `artisan storage:link --force` (idempotent)                               |
| `--with-filament-optimize`    | `true`    | Run `artisan filament:optimize`                                             |
| `--with-horizon-terminate`    | `false`   | Run `artisan horizon:terminate`                                             |
| `--with-api-spec`             | `false`   | Generate OpenAPI spec to `storage/app/private/api.json` (runs the project's `vendor/bin/openapi` binary; your project must have an OpenAPI generator that provides this CLI) |
| `--with-livewire-assets`      | `false`   | Publish Livewire static assets (`vendor:publish --force --tag=livewire:assets`) |
| `--with-npm-build`            | `false`   | Run `npm run build` (Vite / frontend production build)                       |

**Caveats:** `optimize` includes `route:cache`; closure-based routes can make that step fail. If `public/storage` is a regular directory (not a symlink), `storage:link --force` cannot replace it—fix manually or use `--with-storage-link=false`.

#### Examples

```shell
# Full deploy with default PHP
./vendor/bin/deployer

# PHP 8.4, with Horizon termination
./vendor/bin/deployer --php=php8.4 --with-horizon-terminate=true

# Minimal: only caches and optimize, no migrate/link/horizon
./vendor/bin/deployer --with-migrate=false --with-storage-link=false --with-horizon-terminate=false

# Without maintenance-mode
./vendor/bin/deployer --with-maintenance=false

# Include OpenAPI spec generation
./vendor/bin/deployer --with-api-spec=true

# Publish Livewire static assets
./vendor/bin/deployer --with-livewire-assets=true

# Build frontend assets during deploy (npm run build)
./vendor/bin/deployer --with-npm-build=true
```

---

## Installer

The `installer` script runs a one-shot local [Laravel Sail](https://laravel.com/docs/sail) bootstrap from the **project root** (directory containing `artisan`). It checks out your development branch, copies `.env`, installs Composer dependencies via Docker (so `./vendor/bin/sail` exists), starts Sail, runs common Artisan steps, optionally updates `/etc/hosts`, and writes a Git pre-commit hook that runs **[Reviewer](#reviewer)** with Sail-friendly `--php-cmd` / `--composer-cmd` defaults.

**Steps (each can be toggled via options):**

* **Git** — `git checkout` on the main development branch (default `develop`)
* **Env** — `cp .env.example .env` (skipped if `.env` already exists unless `--force-env=true`)
* **Composer** — `docker run` with the Laravel Sail Composer image, `composer install` (optional `--ignore-platform-reqs`, default on)
* **Sail** — `./vendor/bin/sail up -d` by default so the script can continue (see Caveats)
* **Artisan** — `key:generate`; `migrate --seed` (optional)
* **Hosts** — append one line to `/etc/hosts` via `sudo` (optional; skipped if the line is already present)
* **IDE Helper** — `ide-helper:generate` and `ide-helper:meta` (optional, default off)
* **OpenAPI** — `sail php ./vendor/bin/openapi app -o storage/app/private/api.json -f json` (optional)
* **Storage** — `storage:link` (optional)
* **Pre-commit** — `.git/hooks/pre-commit` with `exec ./vendor/bin/reviewer ...` (same pattern as the [wrapper example](#reviewer) in Reviewer; optional)

If `.git` is missing, git checkout and the pre-commit hook are skipped with a short message.

#### Usage

```shell
./vendor/bin/installer \
  --main-dev-branch=develop \
  --composer-docker-image=laravelsail/php84-composer:latest
```

Add to your project’s `composer.json` under `scripts` so you can run `composer install-local` (or another name you prefer):

```json
{
    "scripts": {
        "install-local": "vendor/bin/installer"
    }
}
```

#### Arguments

All boolean options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults are `true` unless noted.

| Argument                         | Default                              | Description |
|----------------------------------|--------------------------------------|-------------|
| `--main-dev-branch`              | `develop`                            | Branch to check out when `--with-git-checkout=true` |
| `--force-env`                    | `false`                              | Overwrite `.env` from `.env.example` if `.env` exists |
| `--composer-docker-image`        | `laravelsail/php84-composer:latest`  | Docker image for `composer install` |
| `--with-ignore-platform-reqs`    | `true`                               | Pass `--ignore-platform-reqs` to Composer |
| `--composer-install-extra-args`  | *(empty)*                            | Extra tokens appended to `composer install` (space-separated) |
| `--sail-bin`                     | `./vendor/bin/sail`                  | Sail script path (used for Artisan, OpenAPI, and hook `reviewer` args) |
| `--sail-detached`                | `true`                               | Run `sail up -d`. If `false`, you must use `--skip-sail-up=true` and start Sail yourself first |
| `--skip-sail-up`                 | `false`                              | Do not run `sail up` (containers already running) |
| `--with-git-checkout`            | `true`                               | Run `git checkout` on `--main-dev-branch` |
| `--with-hosts`                   | `true`                               | Append `--hosts-line` to `/etc/hosts` |
| `--hosts-line`                   | `127.0.0.1 project.test`           | Line appended to `/etc/hosts` |
| `--with-ide-helper`              | `false`                              | Run IDE Helper Artisan commands |
| `--with-openapi`                 | `true`                               | Generate OpenAPI JSON under `storage/app/private/api.json` |
| `--with-migrate-seed`            | `true`                               | Run `migrate --seed` |
| `--with-storage-link`            | `true`                               | Run `storage:link` |
| `--with-pre-commit-hook`         | `true`                               | Write `.git/hooks/pre-commit` to `exec` `reviewer` |
| `--reviewer-hook-args`           | *(empty)*                            | Extra arguments appended to `reviewer` in the hook (e.g. `--with-tests=false`) |

**Caveats:** The installer runs `sail up -d` by default so later Artisan steps are reachable in the same run. A blocking `sail up` would stop the script; use `--skip-sail-up=true` if you start Sail in another terminal first. The first `migrate --seed` can fail if the database container is not ready yet—run migrations again after Sail is healthy. Updating `/etc/hosts` requires `sudo`. IDE Helper requires the `barryvdh/laravel-ide-helper` package. OpenAPI generation requires your project’s `vendor/bin/openapi` CLI. For hook behavior and skipping checks on a single commit, see **[Reviewer](#reviewer)** (`git commit --no-verify`).

#### Examples

```shell
# Full local bootstrap (defaults)
./vendor/bin/installer

# Custom dev branch and hosts entry
./vendor/bin/installer --main-dev-branch=feature/x --hosts-line="127.0.0.1 myapp.test"

# Skip hosts and OpenAPI; enable IDE Helper
./vendor/bin/installer --with-hosts=false --with-openapi=false --with-ide-helper=true

# Sail already running: skip sail up (vendor/ and Sail must already be in place)
./vendor/bin/installer --skip-sail-up=true
```

---

## Spark

The `spark` script prepares your project for a new feature quickly: syncs your main development branch, installs dependencies, runs migrations and cache clear, then prompts for a new feature branch name with a prefilled prefix.

**Steps:**

* **Git sync** — switch to main development branch and pull latest changes from remote
* **Dependencies** — run `composer install` and (when `package.json` exists) `npm install`
* **Laravel prep** — run `artisan migrate` and `artisan optimize:clear` (optional via flags)
* **Feature branch** — prompt with prefilled prefix (default `feature/`), then create and switch to the new branch
* **Finish** — print an inspiration message
* **Optional dev server** — with `--with-npm-dev=true`, run `npm run dev` after setup (blocks until you stop it)

#### Usage

```shell
./vendor/bin/spark \
  --main-dev-branch=develop \
  --feature-branch-prefix=feature/
```

Add to your project’s `composer.json` under `scripts` so you can run `composer spark`:

```json
{
    "scripts": {
        "spark": "vendor/bin/spark --main-dev-branch=develop --feature-branch-prefix=feature/"
    }
}
```

With Laravel Sail:

```json
{
    "scripts": {
        "spark": "vendor/bin/spark --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer' --npm-cmd='./vendor/bin/sail npm' --main-dev-branch=develop --feature-branch-prefix=feature/"
    }
}
```

#### Arguments

All boolean options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults are `true` unless noted.

| Argument                  | Default                         | Description |
|---------------------------|---------------------------------|-------------|
| `--php-cmd`               | `php`                           | PHP command or wrapper (e.g. `php`, `./vendor/bin/sail php`) |
| `--composer-cmd`          | `composer`                      | Composer command (e.g. `composer`, `./vendor/bin/sail composer`) |
| `--npm-cmd`               | `npm`                           | npm command (e.g. `npm`, `pnpm`) |
| `--git-remote-name`       | `origin`                        | Git remote used for pull |
| `--main-dev-branch`       | `develop`                       | Development branch to sync before creating feature branch |
| `--feature-branch-prefix` | `feature/`                      | Default prefix prefilled in the branch prompt |
| `--with-migrate`          | `true`                          | Run `artisan migrate` |
| `--with-cache-clear`      | `true`                          | Run `artisan optimize:clear` |
| `--with-npm-dev`          | `false`                         | After setup, run `npm run dev` (uses `--npm-cmd`; blocks until Ctrl+C) |
| `--inspiration-message`   | `Spark ignited. Build something amazing.` | Message shown after branch creation |

#### Examples

```shell
# Default feature-start flow
./vendor/bin/spark

# Custom prefix for branch naming
./vendor/bin/spark --feature-branch-prefix=feat/

# Skip Laravel prep steps
./vendor/bin/spark --with-migrate=false --with-cache-clear=false

# Start Vite / frontend dev server after branch is ready (blocks the terminal)
./vendor/bin/spark --with-npm-dev=true
```

---

## Rescue

The `rescue` script is the same flow as **[Spark](#spark)**, but prompts for a **bugfix** branch with a prefilled prefix (default `bugfix/`).

**Steps:** identical to Spark — git sync, `composer install`, `npm install` when `package.json` exists, `artisan migrate` / `optimize:clear` (optional), interactive bugfix branch creation, inspiration message, optional `npm run dev`.

#### Usage

```shell
./vendor/bin/rescue \
  --main-dev-branch=develop \
  --bugfix-branch-prefix=bugfix/
```

Add to your project’s `composer.json` under `scripts` so you can run `composer rescue`:

```json
{
    "scripts": {
        "rescue": "vendor/bin/rescue --main-dev-branch=develop --bugfix-branch-prefix=bugfix/"
    }
}
```

With Laravel Sail:

```json
{
    "scripts": {
        "rescue": "vendor/bin/rescue --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer' --npm-cmd='./vendor/bin/sail npm' --main-dev-branch=develop --bugfix-branch-prefix=bugfix/"
    }
}
```

#### Arguments

All boolean options accept `true`, `1`, `yes` or `false`, `0`, `no`. Defaults match Spark except branch naming.

| Argument                  | Default                         | Description |
|---------------------------|---------------------------------|-------------|
| `--php-cmd`               | `php`                           | PHP command or wrapper (e.g. `php`, `./vendor/bin/sail php`) |
| `--composer-cmd`          | `composer`                      | Composer command (e.g. `composer`, `./vendor/bin/sail composer`) |
| `--npm-cmd`               | `npm`                           | npm command (e.g. `npm`, `pnpm`) |
| `--git-remote-name`       | `origin`                        | Git remote used for pull |
| `--main-dev-branch`       | `develop`                       | Development branch to sync before creating bugfix branch |
| `--bugfix-branch-prefix`  | `bugfix/`                       | Default prefix prefilled in the branch prompt |
| `--with-migrate`          | `true`                          | Run `artisan migrate` |
| `--with-cache-clear`      | `true`                          | Run `artisan optimize:clear` |
| `--with-npm-dev`          | `false`                         | After setup, run `npm run dev` (uses `--npm-cmd`; blocks until Ctrl+C) |
| `--inspiration-message`   | `Rescue mission started. Ship the fix.` | Message shown after branch creation |

#### Examples

```shell
# Default bugfix-start flow
./vendor/bin/rescue

# Custom prefix (e.g. fix/)
./vendor/bin/rescue --bugfix-branch-prefix=fix/
```

### TODO

* Allow to merge without running PHP or Composer commands
* Improve the logic of detecting that MR is merged (e.g. check git tags on the main branch)
* Release notes generation based on commit messages
* Main branch name detection
* Latest version detection based on git tags or `config/app.php` file
* Linters (PHPStan, Dumps checker, Pint, Native PHP Linter, OpenAPI doc validation, JS production bundle generation, etc.)

---

### All `composer.json` scripts

Copy the `scripts` block below into your project’s `composer.json` (merge with existing keys). Adjust branch names and flags to match your repo.

**Local PHP / Composer** (no Sail):

```json
{
    "scripts": {
        "release": "vendor/bin/releaser --main-branch=main --main-dev-branch=develop",
        "review": "vendor/bin/reviewer",
        "deploy": "vendor/bin/deployer",
        "install-local": "vendor/bin/installer",
        "spark": "vendor/bin/spark --main-dev-branch=develop --feature-branch-prefix=feature/",
        "rescue": "vendor/bin/rescue --main-dev-branch=develop --bugfix-branch-prefix=bugfix/"
    }
}
```

**Laravel Sail** — same commands with Sail-friendly `php` / `composer` / `npm` wrappers where applicable (`installer` is unchanged; it uses Docker for Composer as documented):

```json
{
    "scripts": {
        "release": "vendor/bin/releaser --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer' --main-branch=main --main-dev-branch=develop",
        "review": "vendor/bin/reviewer --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer'",
        "deploy": "vendor/bin/deployer --php='./vendor/bin/sail php'",
        "install-local": "vendor/bin/installer",
        "spark": "vendor/bin/spark --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer' --npm-cmd='./vendor/bin/sail npm' --main-dev-branch=develop --feature-branch-prefix=feature/",
        "rescue": "vendor/bin/rescue --php-cmd='./vendor/bin/sail php' --composer-cmd='./vendor/bin/sail composer' --npm-cmd='./vendor/bin/sail npm' --main-dev-branch=develop --bugfix-branch-prefix=bugfix/"
    }
}
```
