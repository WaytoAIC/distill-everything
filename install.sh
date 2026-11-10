#!/usr/bin/env bash
# 安装 / 更新 distill-everything skill。幂等：重复执行即更新。
#
# 用 cp 不用 ln -s：软链也能加载，但复制式安装才有机会做下面那道**引用断链自检**——
# SKILL.md 里的 references/xxx.md 按「相对 SKILL.md 所在目录」解析，放错位置时
# AI 读不到也不报错，只会悄悄凭通用知识现编。
#
# 旧版本用「挪走」不用删除：留一份在临时目录，装坏了还能捞回来。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=codex
DEST=""
REMOTE=""
REF=main
FETCH=0
CACHE=""
usage() {
  echo 'Usage: install.sh [--target codex|openclaw|claude] [--dest DIR] [--repo OWNER/REPO] [--ref BRANCH_OR_TAG]'
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --target|--dest|--repo|--ref)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { usage >&2; exit 2; }
      case "$1" in
        --target) TARGET="$2" ;;
        --dest) DEST="$2" ;;
        --repo) REMOTE="$2"; FETCH=1 ;;
        --ref) REF="$2"; FETCH=1 ;;
      esac
      shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$TARGET" in
  codex) DEFAULT_ROOT="${CODEX_HOME:-$HOME/.codex}/skills" ;;
  openclaw) DEFAULT_ROOT="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}/skills" ;;
  claude) DEFAULT_ROOT="${CLAUDE_SKILLS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills}" ;;
  *) usage >&2; exit 2 ;;
esac
if [[ "$FETCH" == 1 ]]; then
  REMOTE="${REMOTE:-WaytoAIC/distill-everything}"
  [[ "$REMOTE" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && "$REF" != -* ]] || { echo 'Invalid repository or ref' >&2; exit 2; }
  CACHE="$(mktemp -d)"
  trap '[[ -z "$CACHE" ]] || rm -rf -- "$CACHE"' EXIT
  git clone --depth 1 --branch "$REF" -- "https://github.com/$REMOTE.git" "$CACHE/source"
  REPO="$CACHE/source"
fi
SRC="$REPO/.claude/skills/distill-everything"
DEST="${DEST:-$DEFAULT_ROOT/distill-everything}"
[[ "$DEST" != / && "$DEST" != "$HOME" && "$DEST" != . && "$DEST" != .. ]] || { echo 'Choose a dedicated skill directory' >&2; exit 2; }
DEST_ROOT="$(dirname "$DEST")"
# Resolve before replacing an installation; never move the source repository.
mkdir -p "$DEST_ROOT"
DEST="$(cd "$DEST_ROOT" && pwd)/$(basename "$DEST")"
case "$REPO/" in "$DEST/"*) echo 'Destination contains source repository' >&2; exit 2 ;; esac
case "$DEST/" in "$REPO/"*) echo 'Destination must be outside source repository' >&2; exit 2 ;; esac
echo "· 安装目标：$TARGET → $DEST"


[[ -f "$SRC/SKILL.md" ]] || { echo "✗ 找不到 $SRC/SKILL.md，请在仓库根目录执行"; exit 1; }

# 保住用户已填好的业务环节清单（私有，永不覆盖）
RINGS="$DEST/references/business-rings.md"
KEEP=""
if [[ -f "$RINGS" ]]; then
  KEEP="$(mktemp)"; cp "$RINGS" "$KEEP"
  echo "· 已备份你填好的 business-rings.md，安装后原样放回"
fi

mkdir -p "$DEST_ROOT"
if [[ -e "$DEST" || -L "$DEST" ]]; then
  OLD="$(mktemp -d)/distill-everything-$(date +%Y%m%d-%H%M%S)"
  mv "$DEST" "$OLD"
  echo "· 旧版本已挪到 ${OLD} (没有删除，装坏了可以捞回来)"
fi
cp -R "$SRC" "$DEST"
[[ -f "$REPO/banner.png" ]] && cp -f "$REPO/banner.png" "$DEST/"

# 放回用户那份；没有就从模板起一份
if [[ -n "$KEEP" ]]; then
  cp "$KEEP" "$RINGS"; rm -f "$KEEP"
else
  cp "$DEST/references/business-rings.template.md" "$RINGS"
  echo "· 已从模板生成 references/business-rings.md —— 🔴 用之前请先填，这份是私有的"
fi

# ── 引用断链自检：SKILL.md 提到的每个 references/*.md 必须真实存在 ──
fail=0
while read -r ref; do
  if [[ -f "$DEST/$ref" ]]; then echo "  ✅ $ref"; else echo "  ❌ 断链 $ref"; fail=1; fi
done < <(grep -o 'references/[a-z.-]*\.md' "$DEST/SKILL.md" | sort -u)
[[ $fail -eq 0 ]] || { echo "✗ 有引用断链，安装中止"; exit 1; }

echo "✓ 装好了 → $DEST"
echo "  试一句：「用蒸馏一切拆一下 <某个仓 / 文章 / 视频链接>」"
