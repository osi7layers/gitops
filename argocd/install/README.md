# Argo CD 설치 가이드

## install 폴더의 목적
공식 HA 매니페스트(v3.5.5)와 우리의 설정을 Kustomize로 묶은 폴더입니다.
공식 파일만 apply하는 경우 손으로 직접 설정한 것이 지워져 해당 폴더를 만들었습니다.
폴더 내용 적용은 Argo CD가 아니라, 사람이 cp-01에서 직접 해야 합니다.

## 설치 순서와 Secret
1. `kubectl create namespace argocd`
2. argocd-aws-creds 만들기
- Argo CD가 EKS(osi7-aws)에서 IAM 사용자 osi7-argocd로 접속할 때 쓰는 키이며, 키는 명호님께 받습니다.

```bash
read -rs AKID && echo
read -rs SECRET && echo
kubectl -n argocd create secret generic argocd-aws-creds \
  --from-literal=AWS_ACCESS_KEY_ID="$AKID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$SECRET"
unset AKID SECRET
```

3. cp-01의 gitops 레포 최상위 폴더(예: `~/gitops-check`)에서 명령어 입력

`kubectl apply --server-side --force-conflicts -k argocd/install`

4. argocd-notifications-secret에 Slack URL 넣기
- Slack URL은 Slack 앱 `osi7-argocd`의 #deploy 채널용 Incoming Webhook을 사용합니다.
```bash
read -rs SLACK_URL && echo

kubectl patch secret argocd-notifications-secret -n argocd --type merge \
  -p "{\"stringData\":{\"slack-url\":\"$SLACK_URL\"}}"

unset SLACK_URL
```
5. osi7-aws 등록
- EKS를 새로 만들면 server와 caData가 바뀌어서 다시 적용이 필요합니다. 
- 어디로 접속하고, 어떤 클러스터 이름으로 로그인하고, 어느 네임스페이스만 쓸지 적은 등록증으로, 엔드포인트와 CA는 명호님께 받습니다.

```yaml
#  ~/osi7-aws-cluster.yaml
apiVersion: v1
kind: Secret
metadata:
  name: osi7-aws
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: osi7-aws
  server: <엔드포인트>
  namespaces: ecommerce-main,ingress-apisix
  config: |
    {
      "awsAuthConfig": {
        "clusterName": "osi7-eks"
      },
      "tlsClientConfig": {
        "caData": "<CA>"
      }
    }
```
```bash
kubectl apply -f ~/osi7-aws-cluster.yaml
```

## 적용 후 확인 할 것
- Pod 모두 Running 상태
- 앱 Synced/Healthy
- UI Settings -> Clusters에서 osi7-aws가 Successful인지
  - Clusters에서 osi7-aws의 연결 상태가 Never로 나오는 경우: `kubectl -n argocd rollout restart statefulset argocd-application-controller` controller 재시작 

## 버전 올리는 법
1. `kustomization.yaml`의 URL에서 `v3.5.5`를 새 버전으로 바꿉니다.
2. `argocd-cm.yaml`의 `resource.exclusions`를 새 버전 기본값으로 바꾼 뒤, 맨 위 EndpointSlice 항목에 `clusters:`와 `- https://kubernetes.default.svc` 2줄을 다시 넣습니다. 
3. 적용 전, cp-01에서 `kubectl diff --server-side --force-conflicts -k argocd/install` 로 무엇이 바뀌는지 미리 확인합니다.
