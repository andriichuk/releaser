## PHP Project Release Flow Automation Script

A small Bash-based release helper for PHP projects. It automates release branch creation, version updates, and post-release branch syncing using simple CLI arguments.

### Requirements

* Bash 
* Git 
* PHP (local or containerized)
* Composer (local or containerized)

### Installation

```shell
composer require andriichuk/releaser --dev
```

### Usage

```shell
./vendor/bin/releaser \
  --php-cmd="./vendor/bin/sail php" \
  --composer-cmd="./vendor/bin/sail composer" \
  --main-branch=main \
  --main-dev-branch=develop
```

### Arguments

| Argument                         | Default            | Description                                                                                                                             |
|----------------------------------|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `--php-cmd`                      | `php`              | PHP command or wrapper to execute (e.g. `php`, `./vendor/bin/sail php`, `docker exec -T app php`)                                       |
| `--composer-cmd`                 | `composer`         | Composer command (e.g. `composer`, `./vendor/bin/sail composer`, `docker exec -T app composer`)                                         |
| `--git-remote-name`              | `origin`           | Git remote name used for fetch, pull, and push                                                                                          |
| `--main-branch`                  | `main`             | Primary production branch                                                                                                               |
| `--main-dev-branch`              | `develop`          | Development branch used for ongoing work                                                                                                |
| `--release-branch-prefix`        | `release/`         | Prefix for release branches                                                                                                             |
| `--with-app-version-update`      | `false`            | Whether to update application version in `config/app.php` file. Please note that the file must exists and contain the `'version'` key.  |
| `--post-release-update-branches` | `$main-dev-branch` | Comma-separated list of branches to update after release (e.g. `develop,stage`, by default value from `--main-dev-branch` will be used) |
| `--with-tests`                   | `true`             | Whether to run tests before creating a release                                                                                          |
| `--with-composer-audit`          | `true`             | Whether to run `composer audit` before creating a release                                                                               |

### TODO

* Release notes generation based on commit messages
* Main branch name detection
* Template for release commit message
* Linters (PHPStan, Dumps checker, Pint, Native PHP Linter, OpenAPI doc validation, JS production bundle generation, etc.)