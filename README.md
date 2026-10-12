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
- 이미지 Tag는 **Jenkins가 자동으로 수정하고 Commit**합니다. 사람이 직접 수정하지 않습니다.
- 이미지 Tag는 Git Commit SHA 기반입니다. `latest`는 사용하지 않습니다.
- 비밀번호, 토큰, 인증서 같은 민감 정보는 이 저장소에 올리지 않습니다.

## 디렉터리 구조 (제안, 확정 시 변경 예정)

> 아직 확정되지 않은 초안입니다. Kubernetes 담당의 Helm/Kustomize 구조와 namespace 이름이 정해지면 그에 맞춰 조정합니다. 실제 폴더는 확정 후 생성합니다. (WBS: GitOps Repository 구성)

```
gitops/
└── apps/
    └── frontend/
        ├── base/                 # 공통 Kubernetes 배포 설정
        └── overlays/             # 환경별 설정 (이름과 단위는 협의 후 확정)
            ├── onprem-dev/
            ├── onprem-main/
            ├── aws-dev/
            └── aws-main/
```

- `develop` 머지 시 개발용 환경, `main` 머지 시 운영용 환경에 배포하는 것을 전제로 합니다.
- 환경 이름과 namespace는 Kubernetes 담당과 협의 중입니다.

## 담당

| 구분                                                    | 담당            |
| ------------------------------------------------------- | --------------- |
| CI/CD & GitOps (Jenkins, 이미지 Tag 갱신, Argo CD 연동) | CI/CD 담당      |
| Kubernetes 매니페스트 구조 (Helm / Kustomize)           | Kubernetes 담당 |
