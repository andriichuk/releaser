## Laravel App Release Script

```shell
.vendor/bin/releaser \
  --php-path="./vendor/bin/sail php" \
  --remote-name=origin \
  --main-branch=main \
  --main-dev-branch=develop \
  --release-branch-prefix="release/" \
  --config-file="./config/app.php"
```