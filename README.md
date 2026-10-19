# gitops

Kubernetes에 배포할 **버전과 설정**을 관리하는 GitOps 저장소입니다.
애플리케이션 소스 코드는 [`osi7layers/app`](https://github.com/osi7layers/app)에서 관리하고, 이 저장소에는 배포 설정만 둡니다.

## 역할

- 컨테이너 이미지는 Harbor(온프레미스)와 ECR(AWS)에 저장됩니다. 이 저장소에는 이미지 자체가 아니라 **어떤 이미지 버전을 배포할지**만 기록합니다.
- Argo CD가 이 저장소의 변경을 감지하여 각 Kubernetes 환경에 반영합니다.

```
GitHub(app) → Jenkins → Harbor / ECR → [이 저장소: 이미지 Tag 갱신] → Argo CD → Kubernetes
```

## 운영 규칙

- 브랜치는 `main` 하나만 사용합니다. 개발용/운영용 환경은 브랜치가 아니라 **폴더**로 구분합니다.
- 개발 환경(`onprem-dev`)의 이미지 Tag는 **Jenkins가 자동으로 수정하고 Commit**합니다. 사람이 직접 수정하지 않습니다.
- 운영 환경(`*-main`)의 이미지 Tag는 **승급 PR로만** 수정합니다.
- 이미지 Tag는 Git Commit SHA 앞 7자리입니다. `latest`는 사용하지 않습니다.
- 비밀번호, 토큰, 인증서 같은 민감 정보는 이 저장소에 올리지 않습니다.

## 디렉터리 구조

우리 서비스는 Helm chart를 Kustomize overlay로 감싸는 방식으로 관리합니다. 모든 환경에 공통인 내용은 `base/`에, 환경마다 다른 값(namespace, 이미지 주소·Tag 등)은 `overlays/<환경>/`에 둡니다.

```
gitops/
├── apps/                              # 우리 서비스 (Kustomize)
│   ├── web/
│   │   ├── base/
│   │   │   └── kustomization.yaml     # 모든 환경 공통 배포 내용 (Helm chart 연결 예정)
│   │   └── overlays/                  # 환경별로 다른 값만
│   │       ├── onprem-dev/
│   │       │   └── kustomization.yaml # ecommerce-dev, Harbor 이미지, Jenkins가 태그 자동 갱신
│   │       ├── onprem-main/
│   │       │   └── kustomization.yaml # ecommerce-main, Harbor 이미지, 승급 PR로 갱신
│   │       └── aws-main/
│   │           └── kustomization.yaml # ecommerce-main, ECR 이미지, 승급 PR로 갱신
│   ├── auth/                          # web과 같은 구조
│   ├── product/                       # web과 같은 구조
│   ├── order/                         # web과 같은 구조
│   └── promotion/                     # web과 같은 구조
├── platform/                          # 외부 도구 Helm values (Argo Rollouts, KEDA, 모니터링) - 예정
├── argocd/
│   ├── root.yaml                      # 루트 Application (처음 한 번만 kubectl apply)
│   └── apps/                          # root가 동기화하는 Application들
│       └── web-onprem-dev.yaml        # web → osi7-onprem ecommerce-dev
└── README.md
```

## 환경

| 환경 (overlay) | 클러스터 | namespace | 이미지 레지스트리 | Tag 갱신 |
| --- | --- | --- | --- | --- |
| `onprem-dev` | osi7-onprem | `ecommerce-dev` | Harbor | Jenkins 자동 |
| `onprem-main` | osi7-onprem | `ecommerce-main` | Harbor | 승급 PR |
| `aws-main` | osi7-aws | `ecommerce-main` | ECR | 승급 PR |

## 배포 흐름

1. app 레포 `main`에 머지되면 Jenkins가 이미지를 빌드해 Harbor에 push하고,
   `apps/<서비스>/overlays/onprem-dev/kustomization.yaml`의 `newTag`를 새 태그로 바꿔 커밋합니다.
2. Argo CD가 변경을 감지해 `ecommerce-dev`에 배포합니다.
3. dev에서 확인한 뒤, 같은 태그를 `onprem-main`, `aws-main`으로 옮기는 PR을 올립니다.
   PR 머지가 운영 배포 승인입니다. 이미지는 다시 빌드하지 않습니다.

## 담당

| 구분 | 담당 |
| --- | --- |
| CI/CD & GitOps (Jenkins, 이미지 Tag 갱신, Argo CD 연동) | CI/CD 담당 |
| Kubernetes 매니페스트 구조 (Helm / Kustomize) | Kubernetes 담당 |
## Argo CD

Argo CD는 온프레미스 클러스터(`osi7-onprem`)의 `argocd` 네임스페이스에 설치되어 있고, `argocd/`의 Application을 **App of Apps** 방식으로 관리합니다.

- `argocd/root.yaml`은 처음 한 번만 `kubectl apply -f argocd/root.yaml`로 올립니다.
- 이후 Application 추가·수정은 `argocd/apps/`에 파일을 커밋하면 root가 자동으로 반영합니다.
- 우리 서비스 매니페스트는 Kustomize가 Helm chart를 감싸므로 `argocd-cm`에 `kustomize.buildOptions: --enable-helm`이 설정되어 있어야 합니다.
