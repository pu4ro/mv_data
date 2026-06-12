# busybox-cache-mounter

Kubernetes PVC에 데이터를 복사하기 위한 busybox 임시 Pod 배포 및 파일 복사 스크립트 모음입니다.

## 구성 파일

| 파일 | 설명 |
|------|------|
| `deployment.yaml` | busybox Pod Deployment 템플릿 |
| `pvc.yaml` | PersistentVolumeClaim 템플릿 |
| `copy-to-data.sh` | Pod 내 `/data`로 파일 복사 스크립트 (tar 스트리밍) |
| `Makefile` | 배포/복사/관리 자동화 |
| `.env.example` | 환경변수 설정 예시 |

## 시작하기

### 1. 환경변수 설정

```bash
cp .env.example .env
```

`.env` 파일을 열어 실제 환경에 맞게 수정합니다.

```env
NAMESPACE=your-namespace
NODE_HOSTNAME=your-node-hostname   # kubectl get nodes
PVC_NAME=vllm-cache
STORAGE_SIZE=80Gi
```

### 2. 배포

```bash
# PVC + Deployment 순서대로 배포
make deploy

# 또는 개별 적용
make apply-pvc
make apply-deployment
```

### 3. 파일 복사

```bash
# 단일 파일
make copy SOURCE=./my-model.bin

# 디렉토리
make copy SOURCE=./my-folder/
```

### 4. 상태 확인

```bash
make status
make logs
```

### 5. 삭제

```bash
# Deployment + PVC 모두 삭제
make delete

# 개별 삭제
make delete-deployment
make delete-pvc
```

## 환경변수 목록

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `NAMESPACE` | `fde-dataops` | Kubernetes 네임스페이스 |
| `DEPLOYMENT_NAME` | `busybox-cache-mounter` | Deployment 이름 |
| `APP_LABEL` | `busybox-cache` | Pod 레이블 |
| `IMAGE` | `cr.makina.rocks/external-hub/busybox:v0.1` | 컨테이너 이미지 |
| `REPLICAS` | `1` | Pod 복제본 수 |
| `NODE_HOSTNAME` | `k3d-test-server-0` | 배포할 노드 호스트네임 |
| `PVC_NAME` | `vllm-cache` | PVC 이름 |
| `STORAGE_SIZE` | `80Gi` | PVC 요청 스토리지 크기 |
| `ACCESS_MODE` | `ReadWriteOnce` | PVC 접근 모드 |
| `STORAGE_CLASS` | _(기본값 사용)_ | 스토리지 클래스 (선택) |
| `TARGET_DIR` | `/data` | Pod 내 복사 대상 경로 |
| `MOUNT_PATH` | `/data` | 볼륨 마운트 경로 |

커맨드라인에서 일시적으로 오버라이드 가능합니다:

```bash
make deploy NAMESPACE=my-ns STORAGE_SIZE=200Gi
```

## 요구사항

- `kubectl` (클러스터 접근 설정 완료)
- `envsubst` (`gettext` 패키지에 포함)
- `tar` (파일 복사에 사용 — 대부분 기본 설치됨)
- `pv` (선택 — 설치돼 있으면 복사 진행률/ETA 표시, 없으면 자동 생략)

> 대용량 모델 파일 복사 시 `kubectl cp`의 메모리/타임아웃 문제를 피하기 위해
> `tar | kubectl exec`로 스트리밍하여 전송합니다.
