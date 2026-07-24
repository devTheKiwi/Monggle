#!/bin/bash
#
# 몽글 원격 설치 — 터미널에 아래 한 줄이면 끝. Xcode 안 필요해요.
#   curl -sL https://raw.githubusercontent.com/devTheKiwi/Monggle/main/remote-install.sh | bash
#
# 릴리스에 올라간 빌드된 앱을 받아서 설치하므로 개발 도구가 전혀 필요 없고,
# 격리 속성(quarantine)을 벗겨서 공증 전이라도 경고 없이 열립니다.
set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

APP="Monggle"
ZIP_URL="https://github.com/devTheKiwi/Monggle/releases/latest/download/Monggle.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo -e "${BOLD}"
echo "  🗓️  몽글 설치"
echo "  맥 메뉴바에 사는 작고 반짝이는 미니 캘린더"
echo -e "${NC}"

# 설치 위치 — 쓸 수 있으면 /Applications, 아니면 ~/Applications
if [ -w /Applications ]; then
    DEST_DIR="/Applications"
else
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi
DEST="$DEST_DIR/$APP.app"

echo -e "${BOLD}[1/3] 최신 버전 내려받는 중...${NC}"
if ! curl -fsSL "$ZIP_URL" -o "$TMP/Monggle.zip"; then
    echo -e "${RED}  다운로드 실패 — 인터넷 연결을 확인해줘.${NC}"
    exit 1
fi

echo -e "${BOLD}[2/3] 설치 중...${NC}"
ditto -x -k "$TMP/Monggle.zip" "$TMP/unpacked"
APP_SRC="$(find "$TMP/unpacked" -maxdepth 2 -name "$APP.app" -type d | head -1)"
if [ -z "$APP_SRC" ]; then
    echo -e "${RED}  업데이트 안에 앱이 없어요.${NC}"
    exit 1
fi

# 켜져 있으면 먼저 종료 (안 그러면 open이 옛 프로세스만 살림)
osascript -e 'quit app "Monggle"' 2>/dev/null || true
pkill -x Monggle 2>/dev/null || true
sleep 1

rm -rf "$DEST"
cp -R "$APP_SRC" "$DEST"

# 공증 전이라 이걸 벗겨야 Gatekeeper 경고 없이 열림
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo -e "${BOLD}[3/3] 실행...${NC}"
open "$DEST"

echo ""
echo -e "${GREEN}  ✅ 설치 완료! 메뉴바 오른쪽 위를 확인해봐 🗓️✨${NC}"
echo "     설정은 메뉴바 아이콘 → ⚙️"
echo "     설치 위치: $DEST"
