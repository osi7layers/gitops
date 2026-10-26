# Argo Rollouts

> **기록용 문서입니다. Argo CD가 자동 배포하지 않습니다.**
> 클러스터에 이미 설치된 상태를 그대로 적어 둔 것입니다. 이 폴더를 고쳐도 클러스터는 바뀌지 않습니다.

## 설치 정보

| 항목 | 값 |
| --- | --- |
| 클러스터 | osi7-oci (온프렘 역할, `onprem-dev` / `onprem-main` 배포 대상) |
| namespace | `argo-rollouts` |
| 설치 방법 | `kubectl apply` (Helm 릴리스 아님) |
| 앱 버전 | `v1.10.1` (`quay.io/argoproj/argo-rollouts:v1.10.1`) |
| 차트 | 없음 |
| 트래픽 라우터 플러그인 | `argoproj-labs/gatewayAPI` v0.17.0 |
| 조회일 | 2026-10-23 |

판단 근거: Deployment에 `app.kubernetes.io/managed-by`, `helm.sh/chart` 라벨이 없고
`kubectl.kubernetes.io/last-applied-configuration` 어노테이션이 있습니다. Argo CD 추적 표시도 없습니다.

## 적용 명령

설치 당시 명령은 남아 있지 않습니다. 아래는 리소스 구성(공식 install.yaml과 같은 라벨)으로 추정한 것입니다.

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/download/v1.10.1/install.yaml

# Gateway API 플러그인 설정과 RBAC는 따로 apply 됨 (아래 발췌 참고)
kubectl apply -f <argo-rollouts-config ConfigMap>
kubectl apply -f <argo-rollouts-gatewayapi ClusterRole / ClusterRoleBinding>
kubectl -n argo-rollouts rollout restart deploy/argo-rollouts
```

## 주요 설정 발췌

### Deployment `argo-rollouts`

```yaml
replicas: 1
serviceAccountName: argo-rollouts
containers:
  - name: argo-rollouts
    image: quay.io/argoproj/argo-rollouts:v1.10.1
    ports:
      - { name: metrics, containerPort: 8090 }
      - { name: healthz, containerPort: 8080 }
    resources:
      limits:
        ephemeral-storage: 1Gi   # cpu/memory requests·limits 없음
```

Service는 `argo-rollouts-metrics`(ClusterIP, 8090) 하나입니다. dashboard는 설치되어 있지 않습니다.

### ConfigMap `argo-rollouts-config`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argo-rollouts-config
  namespace: argo-rollouts
data:
  trafficRouterPlugins: |
    - name: "argoproj-labs/gatewayAPI"
      location: "https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.17.0/gatewayapi-plugin-linux-amd64"
```

### ClusterRole / ClusterRoleBinding `argo-rollouts-gatewayapi`

```yaml
rules:
  - apiGroups: ["gateway.networking.k8s.io"]
    resources: ["httproutes"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
# binding: ServiceAccount argo-rollouts/argo-rollouts
```

### CRD

`rollouts`, `analysisruns`, `analysistemplates`, `clusteranalysistemplates`, `experiments` (`argoproj.io`)
