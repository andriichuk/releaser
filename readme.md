## Laravel App Release Script

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