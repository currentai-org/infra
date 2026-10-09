{{/*
Standard labels, matching normal Helm/Argo chart convention so Argo's resource tracking and any
label-selector tooling (kubectl get -l, dashboards) can find everything this chart deploys.
*/}}
{{- define "agent-service.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
