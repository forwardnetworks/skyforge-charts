{{- define "skyforge.forwardImages.registry" -}}
{{- default "harbor.local.forwardnetworks.com/forward" .Values.skyforge.forwardImages.registry -}}
{{- end -}}

{{- define "skyforge.forwardImages.tag" -}}
{{- trim (default "" .Values.skyforge.forwardImages.tag) -}}
{{- end -}}

{{- define "skyforge.forwardImagePullSecretName" -}}
{{- $global := trim (default "" .Values.skyforge.forwardImages.imagePullSecretName) -}}
{{- $workers := default (dict) .Values.skyforge.forwardCluster.workers -}}
{{- $workerSecret := trim (default "" $workers.imagePullSecretName) -}}
{{- default $global $workerSecret -}}
{{- end -}}

{{- define "skyforge.forwardCollector.image" -}}
{{- $image := trim (default "" .Values.skyforge.forwardCollector.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_collector:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.appserverImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $app := default (dict) $core.appserver -}}
{{- $image := trim (default "" $app.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_appserver:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.backendMasterImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $backend := default (dict) $core.backend -}}
{{- $image := trim (default "" $backend.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_backend_master:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.logserverImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $logs := default (dict) $core.logAggregation -}}
{{- $image := trim (default "" $logs.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_logserver:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.cbrServerImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $cbr := default (dict) $core.cbr -}}
{{- $server := default (dict) $cbr.server -}}
{{- $image := trim (default "" $server.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_cbr_server:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.cbrAgentImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $cbr := default (dict) $core.cbr -}}
{{- $agent := default (dict) $cbr.agent -}}
{{- $image := trim (default "" $agent.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_cbr_agent:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.cbrS3AgentImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $cbr := default (dict) $core.cbr -}}
{{- $agent := default (dict) $cbr.s3Agent -}}
{{- $image := trim (default "" $agent.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_cbr_agent:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.nqeAssistTag" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $assist := default (dict) $core.nqeAssist -}}
{{- $image := trim (default "" $assist.image) -}}
{{- if $image -}}
{{- $parts := splitList ":" $image -}}
{{- if gt (len $parts) 1 -}}
{{- last $parts -}}
{{- end -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if and $tag (regexMatch "^([0-9]+)\\.([0-9]+)\\..*$" $tag) -}}
{{- regexReplaceAll "^([0-9]+\\.[0-9]+)\\..*$" $tag "${1}" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.nqeAssistImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $assist := default (dict) $core.nqeAssist -}}
{{- $image := trim (default "" $assist.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardCore.nqeAssistTag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_nqe_assist:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardCore.bamlImage" -}}
{{- $core := default (dict) .Values.skyforge.forwardCluster.core -}}
{{- $ai := default (dict) $core.ai -}}
{{- $baml := default (dict) $ai.baml -}}
{{- trim (default "" $baml.image) -}}
{{- end -}}

{{- define "skyforge.forwardWorker.computeImage" -}}
{{- $workers := default (dict) .Values.skyforge.forwardCluster.workers -}}
{{- $compute := default (dict) $workers.compute -}}
{{- $image := trim (default "" $compute.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_compute_worker:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "skyforge.forwardWorker.searchImage" -}}
{{- $workers := default (dict) .Values.skyforge.forwardCluster.workers -}}
{{- $search := default (dict) $workers.search -}}
{{- $image := trim (default "" $search.image) -}}
{{- if $image -}}
{{- $image -}}
{{- else -}}
{{- $tag := include "skyforge.forwardImages.tag" . -}}
{{- if $tag -}}
{{- printf "%s/fwd_search_worker:%s" (include "skyforge.forwardImages.registry" .) $tag -}}
{{- end -}}
{{- end -}}
{{- end -}}
