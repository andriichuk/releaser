## PHP Project Release Flow Automation Script

A small Bash-based release helper for PHP projects. It automates release branch creation, version updates, and post-release branch syncing using simple CLI arguments.

<hr>

### Requirements

* Bash 
* Git 
* PHP (local or containerized)

<hr>

### Installation

```shell
composer require andriichuk/releaser --dev
```

<hr>

### Usage

```shell
./vendor/bin/releaser \
  --php-path="./vendor/bin/sail php" \
  --composer-cmd="./vendor/bin/sail composer" \
  --remote-name=origin \
  --main-branch=main \
  --main-dev-branch=develop \
  --release-branch-prefix="release/" \
  --config-file="./config/app.php"
```

<hr>

### Arguments

`--php-path`

Path to the PHP executable used for version updates.

Examples:
 
* Local PHP: `--php-path="php"`
* Docker container: `--php-path="docker compose exec -T app php"`
* Laravel Sail: `--php-path="./vendor/bin/sail php"`

`--composer-cmd`

<hr>

`--remote-name`

Git remote name to push branches to.

Default: `origin`

<hr>

`--main-branch`

Main production branch (e.g., `main` or `master`), default `main`.

<hr>

`--main-dev-branch`

Primary development branch where new features are merged, default `develop`.

<hr>

`--release-branch-prefix`

Prefix for release branches, default `release/`. This will produce branches like: `release/1.0.0`.

<hr>

`--with-app-version-update`

Whether to update the application version during release. Values: `true` or `false`. Default: `false`.

<hr>

`--post-release-update-branches`

Comma-separated list of branches to sync with the main development branch after a release (e.g., `develop,stage`). By default, the main development branch is used.