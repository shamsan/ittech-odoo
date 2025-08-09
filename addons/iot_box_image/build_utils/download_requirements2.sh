#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

require_command git
require_command tar
require_command unxz
require_command unzip
require_command wget

__dir=$1

current_branch="$(git branch --show-current)"
VERSION=${VERSION:-$current_branch}
current_remote=$(git config branch.$VERSION.remote)
if [ -z "$current_remote" ]; then
    echo "Upstream not set for branch '$VERSION'. Setting it to 'origin/$VERSION'..."
    git branch --set-upstream-to=origin/$VERSION $VERSION || {
        echo "Failed to set upstream. Please make sure 'origin/$VERSION' exists."
        exit 1
    }
    current_remote=$(git config branch.$VERSION.remote) # Refresh after setting
fi
# current_remote="origin"
echo "Using branch: ${VERSION}" 
current_repo="$(git remote get-url $current_remote | sed 's/.*github.com[\/:]//' | sed 's/\/ittech-odoo.git//')"
echo "Using repo: ${current_repo}"
REPO="https://github.com/${REPO:-$current_repo}/ittech-odoo.git"
echo "Using repo: ${REPO}"

CLONE_DIR="${OVERWRITE_FILES_BEFORE_INIT_DIR}/home/pi/odoo"
if [ ! -d "$CLONE_DIR" ]; then
    echo "Clone GitHub repo"
    mkdir -pv "${CLONE_DIR}"
    git clone -b ${VERSION} --no-local --no-checkout --depth=1 ${REPO} "${CLONE_DIR}"
    cd "${CLONE_DIR}"
    git config core.sparsecheckout true
    tee -a .git/info/sparse-checkout < "${BUILD_UTILS_DIR}/sparse-checkout" > /dev/null
    git read-tree -mu HEAD
    git remote set-url origin "https://github.com/shamsan/ittech-odoo.git" # ensure remote is the original repozzz
fi
FILES_TO_CHECK=(
    "addons/web"
    "addons/hw_*"
    "addons/iot_base"
    "addons/iot_drivers"
    "addons/iot_box_image/configuration"
    "addons/point_of_sale/tools/posbox/configuration"
    "odoo/"
    "odoo-bin"
    )

    echo "التحقق من الملفات:"
    for path in "${FILES_TO_CHECK[@]}"; do
    # استخدم ls مع glob لتوسيع الأنماط مثل hw_*
    if ls $path &>/dev/null; then
        echo "[✔] موجود: $path"
    else
        echo "[✘] غير موجود: $path"
    fi
    done
cd "${__dir}"

TARGET_DIR="/home/shamsan/Desktop/odoo/odoo-18.3/addons/iot_box_image"
SOURCE_IMAGE="$TARGET_DIR/downloaded_ras/2024-11-19-raspios-bookworm-armhf-lite.img.xz"
DEST_IMAGE="$TARGET_DIR/raspios.img.xz"

# تحقق إذا ما فيه صورة مفكوكة حالياً
if ! ls "$TARGET_DIR"/*raspios*.img 1> /dev/null 2>&1 ; then
    echo "نسخ الصورة من المصدر المحلي..."
    cp "$SOURCE_IMAGE" "$DEST_IMAGE"
    unxz --verbose "$DEST_IMAGE"
fi

# الحصول على اسم الصورة بعد فك الضغط
RASPIOS=$(echo "$TARGET_DIR"/*raspios*.img)

# Download ngrok for ARM and place it in the overwrite directory.
USR_BIN="${OVERWRITE_FILES_BEFORE_INIT_DIR}/usr/bin/"
mkdir -pv "${USR_BIN}"
if ! file_exists "${USR_BIN}/ngrok" ; then
    wget -O /tmp/ngrok.tgz 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz'
    tar xvzf /tmp/ngrok.tgz -C "${USR_BIN}" --remove-files
fi
