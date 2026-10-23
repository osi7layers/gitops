{{- /*
_helpers.tpl : 여러 템플릿이 같이 쓰는 함수 모음 (리소스로 만들어지지 않음)
*/ -}}

{{- /* 리소스 이름 = 릴리스 이름 = 샘플 앱의 서비스 이름 (예: product-service) */ -}}
{{- define "msa-service.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /*
selector 라벨 : Deployment/Service 가 "내 Pod" 를 찾는 라벨
★ 배포 후 변경 불가. 절대 바뀌지 않는 값만 둔다.
*/ -}}
{{- define "msa-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "msa-service.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- /*
일반 라벨 : 조회/모니터링용
 - app: 샘플 앱이 쓰던 라벨. kubectl get pods -l app=product-service 처럼 쓸 수 있게 유지
*/ -}}
{{- define "msa-service.labels" -}}
{{ include "msa-service.selectorLabels" . }}
app: {{ include "msa-service.fullname" . }}
app.kubernetes.io/part-of: {{ .Values.partOf }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- /* 최소 Pod 수 : KEDA → minReplicaCount, HPA → minReplicas, 둘 다 아니면 replicaCount (PDB 생성 여부 판단용) */ -}}
{{- define "msa-service.minPods" -}}
{{- if .Values.keda.enabled -}}
{{- .Values.keda.minReplicaCount -}}
{{- else if .Values.autoscaling.enabled -}}
{{- .Values.autoscaling.minReplicas -}}
{{- else -}}
{{- .Values.replicaCount -}}
{{- end -}}
{{- end -}}

{{- /* Pod 수를 자동 조절하는 장치(HPA 또는 KEDA)가 있는가 → 있으면 Deployment 에 replicas 를 쓰지 않는다 */ -}}
{{- define "msa-service.autoscaled" -}}
{{- if or .Values.autoscaling.enabled .Values.keda.enabled -}}true{{- end -}}
{{- end -}}

{{- /*
Pod 템플릿 : Deployment 와 Rollout 이 똑같이 쓰는 Pod 모양 (이미지, 포트, Probe, 자원, preStop)
 → Rollout 으로 바꿔도 Pod 는 그대로이고 "교체 방식"만 달라진다
*/ -}}
{{- define "msa-service.podTemplate" -}}
metadata:
  labels:
    {{- include "msa-service.labels" . | nindent 4 }}
  {{- if or .Values.config .Values.podAnnotations }}
  annotations:
    {{- if .Values.config }}
    {{- /* 서비스 전용 config 가 바뀌면 해시가 바뀌어 자동으로 롤링 재시작 */}}
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    {{- end }}
    {{- with .Values.podAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
  {{- with .Values.priorityClassName }}
  {{- /* 자원 부족 시 누가 먼저 자리를 차지하나 (지금은 값이 비어 있어 안 들어감) */}}
  priorityClassName: {{ . }}
  {{- end }}
  {{- if .Values.spread.enabled }}
  {{- /* 같은 서비스 Pod 를 노드별로 나눠 배치 (한 노드가 죽어도 다른 노드의 Pod 가 응답) */}}
  topologySpreadConstraints:
    - maxSkew: {{ .Values.spread.maxSkew }}
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: {{ .Values.spread.whenUnsatisfiable }}
      labelSelector:
        matchLabels:
          {{- include "msa-service.selectorLabels" . | nindent 10 }}
      {{- with .Values.spread.matchLabelKeys }}
      {{- /* 같은 버전(ReplicaSet)끼리만 세어서 나눔. 교체 중 예전 Pod 까지 세면 새 Pod 가 한 노드로 몰림 (T-14) */}}
      matchLabelKeys:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  {{- end }}
  {{- with .Values.nodeFailureTolerationSeconds }}
  {{- /* 노드 장애 시 다른 노드로 옮기기 전 대기 시간 (기본 300초 → 이 값) */}}
  tolerations:
    - key: node.kubernetes.io/not-ready
      operator: Exists
      effect: NoExecute
      tolerationSeconds: {{ . }}
    - key: node.kubernetes.io/unreachable
      operator: Exists
      effect: NoExecute
      tolerationSeconds: {{ . }}
  {{- end }}
  {{- with .Values.waitFor }}
  initContainers:
    {{- range . }}
    {{- if .hostEnv }}
    # 공통 설정의 ${{ .hostEnv }}:${{ .portEnv }} 가 열릴 때까지 3초마다 확인 (주소는 ecommerce-config 를 따라감)
    - name: wait-for-{{ .name }}
      image: {{ $.Values.waitForImage }}
      envFrom:
        {{- toYaml $.Values.envFrom | nindent 8 }}
      command: ["sh", "-c", "until nc -z ${{ .hostEnv }} ${{ .portEnv }}; do echo waiting for ${{ .hostEnv }}:${{ .portEnv }}; sleep 3; done"]
    {{- else }}
    # {{ .host }}:{{ .port }} 가 열릴 때까지 3초마다 확인 (주소 고정)
    - name: wait-for-{{ .name }}
      image: {{ $.Values.waitForImage }}
      command: ["sh", "-c", "until nc -z {{ .host }} {{ .port }}; do echo waiting for {{ .host }}:{{ .port }}; sleep 3; done"]
    {{- end }}
      {{- with $.Values.waitForResources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $.Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
  {{- end }}
  containers:
    - name: app
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      ports:
        - name: http
          containerPort: {{ .Values.containerPort }}
          protocol: TCP
        {{- if .Values.managementPort }}
        - name: management
          containerPort: {{ .Values.managementPort }}
          protocol: TCP
        {{- end }}
      {{- if or .Values.config .Values.envFrom }}
      envFrom:
        {{- if .Values.config }}
        - configMapRef:
            name: {{ include "msa-service.fullname" . }}-config
        {{- end }}
        {{- with .Values.envFrom }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- with .Values.env }}
      env:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.startupProbe }}
      startupProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      {{- if .Values.preStopSleepSeconds }}
      lifecycle:
        preStop:
          exec:
            command: ["sh", "-c", "sleep {{ .Values.preStopSleepSeconds }}"]
      {{- end }}
{{- end -}}

{{- /*
Pod 수를 조절할 대상 (HPA·KEDA 의 scaleTargetRef 에 들어감)
 rollout.enabled=true 면 Rollout, 아니면 Deployment
*/ -}}
{{- define "msa-service.scaleTargetRef" -}}
{{- if .Values.rollout.enabled -}}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
{{- else -}}
apiVersion: apps/v1
kind: Deployment
{{- end }}
name: {{ include "msa-service.fullname" . }}
{{- end -}}
