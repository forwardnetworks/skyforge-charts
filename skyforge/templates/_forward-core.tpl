{{- define "skyforge.forwardCore.namespace" -}}
{{- $fc := default (dict) .Values.skyforge.forwardCluster -}}
{{- $core := default (dict) $fc.core -}}
{{- default $fc.serviceNamespace $core.namespace -}}
{{- end -}}

{{- define "skyforge.forwardCore.imagePullSecrets" -}}
{{- $secretName := include "skyforge.forwardImagePullSecretName" . -}}
{{- if $secretName }}
imagePullSecrets:
  - name: {{ $secretName | quote }}
{{- end }}
{{- end -}}

{{- define "skyforge.forwardCore.appserverSettings" -}}
{{- $forwardCluster := default (dict) .Values.skyforge.forwardCluster -}}
{{- $publicHostname := trim (default "" $forwardCluster.hostname) -}}
{{- $baseUrl := "" -}}
{{- if $publicHostname -}}
  {{- $baseUrl = printf "https://%s" $publicHostname -}}
{{- else -}}
  {{- $baseUrl = required "skyforge.forward.baseUrl is required when skyforge.forwardCluster.core.owner=skyforge and skyforge.forwardCluster.hostname is unset" .Values.skyforge.forward.baseUrl -}}
{{- end -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $cbr := default (dict) $core.cbr -}}
{{- $settings := list (printf "-Dforward.baseurl=%s" $baseUrl) "-Duploads.tmpdir=/tmp" -}}
{{- if default false $cbr.enabled -}}
  {{- $server := default (dict) $cbr.server -}}
  {{- $settings = append $settings (printf "-Dcbr.server.host=fwd-cbr-server.%s.svc.cluster.local" (include "skyforge.forwardCore.namespace" .)) -}}
  {{- $settings = append $settings (printf "-Dcbr.server.grpc.port=%v" (default 40100 (default (dict) $server.service).grpcPort)) -}}
{{- end -}}
{{- join " " $settings -}}
{{- end -}}

{{- define "skyforge.forwardCore.appserverLogForwarderConfig" -}}
{{- if .enabled }}
fluent-bit.conf: |
  [INPUT]
      Name              tail
      Tag               fwd.appserver.${K8S_NODE_NAME}
      Path              {{ .logsDir }}/appserver
      DB                {{ .logsDir }}/flb_appserver.db
      DB.journal_mode   OFF
      Mem_Buf_Limit     5MB
      Skip_Long_Lines   On

  [INPUT]
      Name              tail
      Tag               fwd.audit.${K8S_NODE_NAME}
      Path              {{ .logsDir }}/audit
      DB                {{ .logsDir }}/flb_audit.db
      DB.journal_mode   OFF
      Mem_Buf_Limit     5MB
      Skip_Long_Lines   On
  {{- range .outputs }}

  [OUTPUT]
      Name              forward
      Match             *
      Host              {{ .host }}
      Port              {{ .port }}
  {{- end }}
{{- end }}
{{- end -}}
