#!/bin/bash
set -euo pipefail

# 파일 복사 스크립트 (tar 스트리밍) for busybox-cache-mounter deployment

NAMESPACE="${NAMESPACE:-fde-dataops}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-busybox-cache-mounter}"
APP_LABEL="${APP_LABEL:-busybox-cache}"
TARGET_DIR="${TARGET_DIR:-/data}"

# 사용법 출력
usage() {
    cat << USAGE
Usage: $0 [OPTIONS] <source_file_or_directory>

Description:
    Kubernetes Pod로 파일이나 디렉토리를 복사하는 스크립트입니다.
    busybox-cache-mounter deployment의 Pod를 찾아서 $TARGET_DIR 디렉토리로 복사합니다.

Options:
    -h, --help    도움말 출력

Arguments:
    source_file_or_directory    복사할 소스 파일 또는 디렉토리 경로

Environment:
    NAMESPACE: $NAMESPACE
    DEPLOYMENT: $DEPLOYMENT_NAME
    TARGET_DIR: $TARGET_DIR

Examples:
    $0 ./my-model.bin          # 단일 파일 복사
    $0 ./my-folder/            # 디렉토리 복사
    $0 -h                      # 도움말 출력

USAGE
}

# 인자 확인 및 help 옵션 처리
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
    exit 0
fi

SOURCE="$1"

# 소스 파일/디렉토리 존재 확인
if [ ! -e "$SOURCE" ]; then
    echo "Error: Source '$SOURCE' does not exist"
    exit 1
fi

# Pod 찾기
echo "Finding pod for deployment $DEPLOYMENT_NAME in namespace $NAMESPACE..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=$APP_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
    echo "Error: No pod found for deployment $DEPLOYMENT_NAME in namespace $NAMESPACE"
    echo "Please check if the deployment is running:"
    echo "  kubectl get pods -n $NAMESPACE -l app=$APP_LABEL"
    exit 1
fi

echo "Found pod: $POD_NAME"

# tar 스트림 전송 (kubectl cp는 대용량 파일에서 메모리/타임아웃 문제가 있어 회피)
# 로컬에서 tar로 스트리밍 → Pod 내부 tar로 풀기
SRC_DIR=$(dirname "$SOURCE")
SRC_BASE=$(basename "$SOURCE")

# pv가 있으면 진행률 표시, 없으면 일반 전송으로 폴백
if command -v pv >/dev/null 2>&1; then
    # 전체 크기를 구해 ETA/퍼센트 표시 (du -b 미지원 환경은 크기 없이 진행)
    SRC_SIZE=$(du -sb "$SOURCE" 2>/dev/null | cut -f1 || true)
    if [ -n "$SRC_SIZE" ]; then
        PV_CMD="pv -s $SRC_SIZE"
    else
        PV_CMD="pv"
    fi
else
    PV_CMD="cat"
fi

echo "Streaming $SOURCE to $POD_NAME:$TARGET_DIR/ via tar ..."
if tar cf - -C "$SRC_DIR" "$SRC_BASE" \
    | $PV_CMD \
    | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- tar xf - -C "$TARGET_DIR"; then
    echo "Successfully copied $SOURCE to $POD_NAME:$TARGET_DIR/"

    # 복사된 파일 확인
    echo ""
    echo "Files in $TARGET_DIR:"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ls -lh "$TARGET_DIR/"
else
    echo "Error: Failed to copy files"
    exit 1
fi
