#!/usr/bin/env bash

set -ex

CLANG_VERSION="${VERSION:-16}"
CLANG_INSTALL_ALL=all
CLANG_PRIORITY=${CLANG_VERSION}

# List of packages to check and install
packages=(lsb-release wget software-properties-common gpg)

# update apt cache
apt update

for package in "${packages[@]}"; do
  # Check if the package is installed
  if ! command -v "$package" >/dev/null 2>&1; then
    echo "$package not found. Installing..."
    DEBIAN_FRONTEND=noninteractive apt install --yes "$package"
  fi
done

# cleanup apt cache
rm -rf /var/lib/apt/lists/*

# download and run the installer
INSTALLER_PATH="/tmp/llvm.sh"
wget -q -O "$INSTALLER_PATH" https://apt.llvm.org/llvm.sh
chmod +x "$INSTALLER_PATH"
"$INSTALLER_PATH" "${CLANG_VERSION}" "${CLANG_INSTALL_ALL}"
rm "$INSTALLER_PATH"

update-alternatives \
  --verbose \
  --install /usr/bin/llvm-config llvm-config "/usr/bin/llvm-config-${CLANG_VERSION}" "${CLANG_PRIORITY}" \
  --slave /usr/bin/llvm-ar llvm-ar "/usr/bin/llvm-ar-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-as llvm-as "/usr/bin/llvm-as-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-bcanalyzer llvm-bcanalyzer "/usr/bin/llvm-bcanalyzer-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-cov llvm-cov "/usr/bin/llvm-cov-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-diff llvm-diff "/usr/bin/llvm-diff-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-dis llvm-dis "/usr/bin/llvm-dis-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-dwarfdump llvm-dwarfdump "/usr/bin/llvm-dwarfdump-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-extract llvm-extract "/usr/bin/llvm-extract-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-link llvm-link "/usr/bin/llvm-link-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-mc llvm-mc "/usr/bin/llvm-mc-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-nm llvm-nm "/usr/bin/llvm-nm-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-objdump llvm-objdump "/usr/bin/llvm-objdump-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-ranlib llvm-ranlib "/usr/bin/llvm-ranlib-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-readobj llvm-readobj "/usr/bin/llvm-readobj-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-rtdyld llvm-rtdyld "/usr/bin/llvm-rtdyld-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-size llvm-size "/usr/bin/llvm-size-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-stress llvm-stress "/usr/bin/llvm-stress-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-symbolizer llvm-symbolizer "/usr/bin/llvm-symbolizer-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-tblgen llvm-tblgen "/usr/bin/llvm-tblgen-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-objcopy llvm-objcopy "/usr/bin/llvm-objcopy-${CLANG_VERSION}" \
  --slave /usr/bin/llvm-strip llvm-strip "/usr/bin/llvm-strip-${CLANG_VERSION}"

update-alternatives \
  --verbose \
  --install /usr/bin/clang clang "/usr/bin/clang-${CLANG_VERSION}" "${CLANG_PRIORITY}" \
  --slave /usr/bin/clangd clangd "/usr/bin/clangd-${CLANG_VERSION}" \
  --slave /usr/bin/clang++ clang++ "/usr/bin/clang++-${CLANG_VERSION}" \
  --slave /usr/bin/asan_symbolize asan_symbolize "/usr/bin/asan_symbolize-${CLANG_VERSION}" \
  --slave /usr/bin/clang-cpp clang-cpp "/usr/bin/clang-cpp-${CLANG_VERSION}" \
  --slave /usr/bin/clang-check clang-check "/usr/bin/clang-check-${CLANG_VERSION}" \
  --slave /usr/bin/clang-cl clang-cl "/usr/bin/clang-cl-${CLANG_VERSION}" \
  --slave /usr/bin/ld.lld ld.lld "/usr/bin/ld.lld-${CLANG_VERSION}" \
  --slave /usr/bin/lld lld "/usr/bin/lld-${CLANG_VERSION}" \
  --slave /usr/bin/lld-link lld-link "/usr/bin/lld-link-${CLANG_VERSION}" \
  --slave /usr/bin/clang-format clang-format "/usr/bin/clang-format-${CLANG_VERSION}" \
  --slave /usr/bin/clang-format-diff clang-format-diff "/usr/bin/clang-format-diff-${CLANG_VERSION}" \
  --slave /usr/bin/clang-include-fixer clang-include-fixer "/usr/bin/clang-include-fixer-${CLANG_VERSION}" \
  --slave /usr/bin/clang-offload-bundler clang-offload-bundler "/usr/bin/clang-offload-bundler-${CLANG_VERSION}" \
  --slave /usr/bin/clang-query clang-query "/usr/bin/clang-query-${CLANG_VERSION}" \
  --slave /usr/bin/clang-rename clang-rename "/usr/bin/clang-rename-${CLANG_VERSION}" \
  --slave /usr/bin/clang-reorder-fields clang-reorder-fields "/usr/bin/clang-reorder-fields-${CLANG_VERSION}" \
  --slave /usr/bin/clang-tidy clang-tidy "/usr/bin/clang-tidy-${CLANG_VERSION}" \
  --slave /usr/bin/lldb lldb "/usr/bin/lldb-${CLANG_VERSION}" \
  --slave /usr/bin/lldb-server lldb-server "/usr/bin/lldb-server-${CLANG_VERSION}"

echo "Done"
