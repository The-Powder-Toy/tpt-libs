set -euo pipefail
IFS=$'\t\n'

gh release create --verify-tag --title $GITHUB_REF_NAME $GITHUB_REF_NAME
