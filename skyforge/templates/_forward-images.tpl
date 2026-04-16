{{- define "skyforge.forwardImages.registry" -}}
{{- default "harbor.local.forwardnetworks.com/forward" .Values.skyforge.forwardImages.registry -}}
{{- end -}}

{{- define "skyforge.forwardImages.tag" -}}
{{- trim (default "" .Values.skyforge.forwardImages.tag) -}}
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
