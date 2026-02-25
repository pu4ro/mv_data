# .env 파일 로드 (파일이 있을 경우에만)
ifneq (,$(wildcard .env))
  include .env
  export
endif

# 기본값
NAMESPACE         ?= fde-dataops
DEPLOYMENT_NAME   ?= busybox-cache-mounter
APP_LABEL         ?= busybox-cache
IMAGE             ?= cr.makina.rocks/external-hub/busybox:v0.1
REPLICAS          ?= 1
NODE_HOSTNAME     ?= k3d-test-server-0
PVC_NAME          ?= vllm-cache
STORAGE_SIZE      ?= 80Gi
ACCESS_MODE       ?= ReadWriteOnce
TARGET_DIR        ?= /data
MOUNT_PATH        ?= /data

# envsubst로 치환할 변수 목록
ENVSUBST_VARS = $${NAMESPACE} $${DEPLOYMENT_NAME} $${APP_LABEL} $${IMAGE} \
                $${REPLICAS} $${NODE_HOSTNAME} $${PVC_NAME} $${STORAGE_SIZE} \
                $${ACCESS_MODE} $${TARGET_DIR} $${MOUNT_PATH}

.PHONY: help deploy apply-pvc apply-deployment copy status logs delete delete-deployment delete-pvc

## 도움말
help:
	@echo ""
	@echo "Usage: make <target> [SOURCE=<path>]"
	@echo ""
	@echo "Targets:"
	@echo "  deploy              PVC + Deployment 순서대로 배포"
	@echo "  apply-pvc           pvc.yaml 적용"
	@echo "  apply-deployment    deployment.yaml 적용"
	@echo "  copy SOURCE=<path>  Pod의 $(TARGET_DIR)로 파일/디렉토리 복사"
	@echo "  status              Pod 상태 확인"
	@echo "  logs                Pod 로그 확인"
	@echo "  delete              Deployment + PVC 삭제"
	@echo "  delete-deployment   Deployment만 삭제"
	@echo "  delete-pvc          PVC만 삭제"
	@echo ""
	@echo "현재 설정 (.env):"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  DEPLOYMENT_NAME=$(DEPLOYMENT_NAME)"
	@echo "  APP_LABEL=$(APP_LABEL)"
	@echo "  IMAGE=$(IMAGE)"
	@echo "  NODE_HOSTNAME=$(NODE_HOSTNAME)"
	@echo "  PVC_NAME=$(PVC_NAME)"
	@echo "  STORAGE_SIZE=$(STORAGE_SIZE)"
	@echo "  TARGET_DIR=$(TARGET_DIR)"
	@echo ""

## PVC + Deployment 순서대로 배포
deploy: apply-pvc apply-deployment
	@echo "✓ 배포 완료"

## pvc.yaml 환경변수 치환 후 적용
apply-pvc:
	@echo "Applying PVC: $(PVC_NAME) in namespace $(NAMESPACE)..."
	envsubst '$(ENVSUBST_VARS)' < pvc.yaml | kubectl apply -f -

## deployment.yaml 환경변수 치환 후 적용
apply-deployment:
	@echo "Applying Deployment: $(DEPLOYMENT_NAME) in namespace $(NAMESPACE)..."
	envsubst '$(ENVSUBST_VARS)' < deployment.yaml | kubectl apply -f -

## Pod로 파일/디렉토리 복사 (make copy SOURCE=./파일경로)
copy:
ifndef SOURCE
	$(error SOURCE is not set. Usage: make copy SOURCE=<path>)
endif
	@bash copy-to-data.sh "$(SOURCE)"

## Pod 상태 확인
status:
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE) -l app=$(APP_LABEL) -o wide
	@echo ""
	@echo "=== Deployment ==="
	kubectl get deployment $(DEPLOYMENT_NAME) -n $(NAMESPACE)
	@echo ""
	@echo "=== PVC ==="
	kubectl get pvc $(PVC_NAME) -n $(NAMESPACE)

## Pod 로그 확인
logs:
	$(eval POD_NAME := $(shell kubectl get pods -n $(NAMESPACE) -l app=$(APP_LABEL) -o jsonpath='{.items[0].metadata.name}' 2>/dev/null))
	@if [ -z "$(POD_NAME)" ]; then echo "Error: Pod not found"; exit 1; fi
	kubectl logs -n $(NAMESPACE) $(POD_NAME) --tail=100 -f

## Deployment + PVC 삭제
delete: delete-deployment delete-pvc

## Deployment만 삭제
delete-deployment:
	kubectl delete deployment $(DEPLOYMENT_NAME) -n $(NAMESPACE) --ignore-not-found

## PVC만 삭제
delete-pvc:
	kubectl delete pvc $(PVC_NAME) -n $(NAMESPACE) --ignore-not-found
