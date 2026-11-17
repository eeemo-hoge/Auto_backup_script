#!/usr/bin/env bash
set -euo pipefail

KEEP=120
LOG_DIR="/var/log/backup"
REQUIRE_MOUNT=true

EXCLUDES=(
  "/dev/*"
  "/proc/*"
  "/sys/*"
  "/tmp/*"
  "/run/*"
  "/mnt/*"
  "/media/*"
  "/timeshift/*"
  "/lost+found"
  "/swapfile"
  "/var/tmp/*"
  "/var/cache/*"
  "/home/*/.cache/*"
  "/home/*/.local/share/Trash/*"
)

log() { echo "[$(date '+%F %T')] $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

if (($# < 1)); then
  die "使い方: $0 MOUNT_POINT [--dry-run]"
fi

MOUNT_POINT=$1
shift

DRY_RUN_ARGS=()
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY_RUN_ARGS=(--dry-run)
  shift
fi
(($# == 0)) || die "使い方: $0 MOUNT_POINT [--dry-run]"

DEST="$MOUNT_POINT/backup/$(hostname -s)"

[[ $EUID -eq 0 ]] || die "root で実行してください (sudo bash $0 $MOUNT_POINT)"
command -v rsync >/dev/null || die "rsync がインストールされていません"
[[ -d "$MOUNT_POINT" ]] || die "$MOUNT_POINT が存在しません"

if [[ "$REQUIRE_MOUNT" == true ]] && ! mountpoint -q "$MOUNT_POINT"; then
  die "$MOUNT_POINT がマウントされていません"
fi

mkdir -p "$DEST"

FSTYPE=$(stat -f -c %T "$DEST")
case "$FSTYPE" in
  msdos|vfat|exfat|fuseblk|ntfs*)
    die "$DEST のファイルシステム ($FSTYPE) は Linux の権限を保存できません"
    ;;
esac

exec 9>/run/backup.sh.lock
flock -n 9 || die "別のバックアップが実行中です"

mkdir -p "$LOG_DIR"

# ナノ秒まで含め、同じ分に複数回実行しても世代名が重ならないようにする
STAMP=$(date '+%Y-%m-%d_%H%M%S_%N')
MOUNT_NAME=$(basename -- "$MOUNT_POINT")
LOG_FILE="$LOG_DIR/backup_${MOUNT_NAME}_${STAMP}.log"

PROGRESS_ARGS=()
if [[ -t 1 ]]; then
  PROGRESS_ARGS=(--info=progress2 --no-inc-recursive)
fi

exec > >(tee -a "$LOG_FILE") 2>&1

TARGET="$DEST/$STAMP"
LATEST="$DEST/latest"

EXCLUDE_ARGS=()
for e in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$e")
done
EXCLUDE_ARGS+=(--exclude="$MOUNT_POINT/*")

LINK_ARGS=()
if [[ -d "$LATEST" ]]; then
  LINK_ARGS=(--link-dest="$(readlink -f "$LATEST")")
  log "前回のバックアップ: $(readlink -f "$LATEST")"
else
  log "初回バックアップ(フルコピー)"
fi

DRY_RUN_LABEL=""
if ((${#DRY_RUN_ARGS[@]})); then
  DRY_RUN_LABEL=" (dry-run)"
fi

log "バックアップ開始: / -> $TARGET$DRY_RUN_LABEL"

set +e
rsync -aAXH --numeric-ids --delete --info=stats2 \
  "${PROGRESS_ARGS[@]}" \
  "${DRY_RUN_ARGS[@]}" \
  "${LINK_ARGS[@]}" \
  "${EXCLUDE_ARGS[@]}" \
  / "$TARGET/"
RC=$?
set -e

# rsync の終了コード 24 は、転送中にファイルが消えた場合として許容
if [[ $RC -ne 0 && $RC -ne 24 ]]; then
  die "rsync が失敗しました (exit $RC)。latest は更新しません"
fi

if ((${#DRY_RUN_ARGS[@]})); then
  log "dry-run 完了(何も書き込んでいません)"
  exit 0
fi

ln -sfn "$TARGET" "$LATEST"
log "latest -> $TARGET"

mapfile -t GENS < <(
  find "$DEST" -mindepth 1 -maxdepth 1 -type d \
    -regextype posix-extended \
    -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}_[0-9]{9}' |
    sort
)

COUNT=${#GENS[@]}
if ((COUNT > KEEP)); then
  for old in "${GENS[@]:0:COUNT-KEEP}"; do
    log "古い世代を削除: $old"
    rm -rf --one-file-system "$old"
  done
fi

ls -1t "$LOG_DIR"/backup_"$MOUNT_NAME"_*.log 2>/dev/null |
  tail -n +$((KEEP + 1)) |
  xargs -r rm -f --

log "バックアップ完了 (exit $RC)"
