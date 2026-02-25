#!/bin/bash

# kubectl cp 스크립트 for busybox-cache-mounter deployment

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
    busybox-cache-mounter deployment의 Pod를 찾아서 /data 디렉토리로 복사합니다.

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
    exit 1
}

# 인자 확인 및 help 옵션 처리
if [ $# -eq 0 ]; then
    usage
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
fi

SOURCE="$1"

# 소스 파일/디렉토리 존재 확인
if [ ! -e "$SOURCE" ]; then
    echo "Error: Source '$SOURCE' does not exist"
    exit 1
fi

# Pod 찾기
echo "Finding pod for deployment $DEPLOYMENT_NAME in namespace $NAMESPACE..."
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "Error: No pod found for deployment $DEPLOYMENT_NAME in namespace $NAMESPACE"
    echo "Please check if the deployment is running:"
    echo "  kubectl get pods -n $NAMESPACE -l app=$APP_LABEL"
    exit 1
fi

echo "Found pod: $POD_NAME"

# kubectl cp 실행
echo "Copying $SOURCE to $POD_NAME:$TARGET_DIR/ ..."
kubectl cp "$SOURCE" "$NAMESPACE/$POD_NAME:$TARGET_DIR/"

if [ $? -eq 0 ]; then
    echo "Successfully copied $SOURCE to $POD_NAME:$TARGET_DIR/"

    # 복사된 파일 확인
    echo ""
    echo "Files in $TARGET_DIR:"
    kubectl exec -n $NAMESPACE $POD_NAME -- ls -lh $TARGET_DIR/
else
    echo "Error: Failed to copy files"
    exit 1
fi
