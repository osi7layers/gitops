# KEDA

> **기록용 문서입니다. Argo CD가 자동 배포하지 않습니다.**
> 클러스터에 이미 설치된 상태를 그대로 적어 둔 것입니다. 이 폴더를 고쳐도 클러스터는 바뀌지 않습니다.

## 설치 정보

| 항목 | 값 |
| --- | --- |
| 클러스터 | osi7-oci (온프렘 역할, `onprem-dev` / `onprem-main` 배포 대상) |
| namespace | `keda` |
| 설치 방법 | Helm 릴리스 `keda` (revision 1, 2026-10-19) |
| 차트 | `kedacore/keda` `2.21.0` |
| 앱 버전 | `2.21.0` |
| 조회일 | 2026-10-23 |

## 적용 명령

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --version 2.21.0 -n keda --create-namespace
```

## 주요 설정 발췌

`helm get values keda -n keda` 결과 사용자 지정 값이 없습니다(`null`). 차트 기본값 그대로입니다.
기본값 그대로라 [values.yaml](values.yaml)은 비어 있습니다.

| Deployment | 이미지 | requests | limits |
| --- | --- | --- | --- |
| `keda-operator` | `ghcr.io/kedacore/keda:2.21.0` | cpu 100m / mem 100Mi | cpu 1 / mem 1000Mi |
| `keda-operator-metrics-apiserver` | `ghcr.io/kedacore/keda-metrics-apiserver:2.21.0` | cpu 100m / mem 100Mi | cpu 1 / mem 1000Mi |
| `keda-admission-webhooks` | `ghcr.io/kedacore/keda-admission-webhooks:2.21.0` | cpu 100m / mem 100Mi | cpu 1 / mem 1000Mi |

APIService `v1beta1.external.metrics.k8s.io` → `keda/keda-operator-metrics-apiserver`
