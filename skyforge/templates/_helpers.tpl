{{- define "skyforge.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "skyforge.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "skyforge.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.labels" -}}
app.kubernetes.io/name: {{ include "skyforge.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "skyforge.traefikLabels" -}}
app.kubernetes.io/name: traefik
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Read a value from an existing Secret (if present), otherwise use the provided
fallback. This is used to keep Helm upgrades stable when secret values are
managed out-of-band (for example, via deploy/skyforge-secrets.yaml) while still
allowing fresh installs to supply values via Helm values.

Args:
  0: context (.)
  1: secret name
  2: secret key
  3: fallback string (unencoded)
*/}}
{{- define "skyforge.secretOrValue" -}}
{{- $ctx := index . 0 -}}
{{- $name := index . 1 -}}
{{- $key := index . 2 -}}
{{- $fallback := index . 3 | default "" -}}
{{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace $name -}}
{{- if and $existing (index $existing.data $key) -}}
{{- index $existing.data $key | b64dec -}}
{{- else -}}
{{- $fallback -}}
{{- end -}}
{{- end -}}
