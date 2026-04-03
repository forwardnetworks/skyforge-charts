{{- define "skyforge.forwardWorker.probes" -}}
startupProbe:
  tcpSocket:
    port: {{ .port }}
  initialDelaySeconds: {{ default 10 .initialDelaySeconds }}
  failureThreshold: {{ default 10 .failureThreshold }}
readinessProbe:
  tcpSocket:
    port: {{ .port }}
livenessProbe:
  tcpSocket:
    port: {{ .port }}
  periodSeconds: {{ default 60 .periodSeconds }}
  failureThreshold: {{ default 10 .failureThreshold }}
  timeoutSeconds: {{ default 3 .timeoutSeconds }}
{{- end -}}

{{- define "skyforge.forwardWorker.postgresEnv" -}}
{{- $db := .db -}}
{{- $mode := .mode -}}
{{- if eq $mode "external" }}
- name: EXTERNAL_DB_SETTINGS
  value: "-Djdbc.ssl.mode={{ default "DISABLE" $db.sslMode }}{{ if $db.certificate }} -Djdbc.ssl.root_cert_path=/opt/forward/{{ $db.certificate }}{{ end }}{{ if $db.port }} -Djdbc.postgres_port={{ $db.port }}{{ end }}"
- name: POSTGRES_HOST
  value: {{ required "skyforge.forwardCluster.workers.database.appHost is required when owner=skyforge and database.mode=external" $db.appHost | quote }}
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ required "skyforge.forwardCluster.workers.database.appCredentialsSecretName is required when owner=skyforge" $db.appCredentialsSecretName | quote }}
      key: {{ default "user" $db.appUserKey | quote }}
- name: POSTGRES_PASS
  valueFrom:
    secretKeyRef:
      name: {{ required "skyforge.forwardCluster.workers.database.appCredentialsSecretName is required when owner=skyforge" $db.appCredentialsSecretName | quote }}
      key: {{ default "password" $db.appPasswordKey | quote }}
- name: FDB_POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ required "skyforge.forwardCluster.workers.database.fdbExternalCredentialsSecretName is required when owner=skyforge and database.mode=external" $db.fdbExternalCredentialsSecretName | quote }}
      key: {{ default "user" $db.fdbUserKey | quote }}
- name: FDB_POSTGRES_PASS
  valueFrom:
    secretKeyRef:
      name: {{ required "skyforge.forwardCluster.workers.database.fdbExternalCredentialsSecretName is required when owner=skyforge and database.mode=external" $db.fdbExternalCredentialsSecretName | quote }}
      key: {{ default "password" $db.fdbPasswordKey | quote }}
- name: FDB_PARAMS
  value: >-
    -Dfdb.jdbc.postgres_servers={{ required "skyforge.forwardCluster.workers.database.fdbHost is required when owner=skyforge and database.mode=external" $db.fdbHost }}
    -Dfdb.jdbc.postgres_port={{ default 5432 $db.port }}
    -Dfdb.jdbc.username=$(FDB_POSTGRES_USER)
    -Dfdb.jdbc.passwords=$(FDB_POSTGRES_PASS)
{{- else }}
- name: POSTGRES_HOST
  value: "fwd-pg-app"
- name: POSTGRES_USER
  value: "postgres"
- name: POSTGRES_PASS
  valueFrom:
    secretKeyRef:
      name: {{ default "postgres.fwd-pg-app.credentials" $db.appCredentialsSecretName | quote }}
      key: {{ default "password" $db.appPasswordKey | quote }}
- name: FDB_PG_PASSWORD_PARTITION_0
  valueFrom:
    secretKeyRef:
      name: {{ default "postgres.fwd-pg-fdb-0.credentials" $db.fdbInternalPartition0SecretName | quote }}
      key: {{ default "password" $db.fdbPartitionPasswordKey | quote }}
- name: FDB_PG_PASSWORD_PARTITION_1
  valueFrom:
    secretKeyRef:
      name: {{ default "postgres.fwd-pg-fdb-1.credentials" $db.fdbInternalPartition1SecretName | quote }}
      key: {{ default "password" $db.fdbPartitionPasswordKey | quote }}
- name: FDB_PARAMS
  value: >-
    -Dfdb.jdbc.postgres_servers=fwd-pg-fdb-0,fwd-pg-fdb-1
    -Dfdb.jdbc.passwords=$(FDB_PG_PASSWORD_PARTITION_0),$(FDB_PG_PASSWORD_PARTITION_1)
{{- end }}
{{- end -}}

{{- define "skyforge.forwardWorker.dbVolumes" -}}
{{- if and (eq .mode "external") .certificate }}
- name: db-cert-volume
  configMap:
    name: db-cert
{{- end }}
{{- end -}}

{{- define "skyforge.forwardWorker.dbVolumeMounts" -}}
{{- if and (eq .mode "external") .certificate }}
- mountPath: /opt/forward/{{ .certificate }}
  name: db-cert-volume
  subPathExpr: {{ .certificate }}
{{- end }}
{{- end -}}

{{- define "skyforge.forwardWorker.logForwarderContainer" -}}
{{- if .enabled }}
- name: log-forwarder
  image: {{ .image | quote }}
  imagePullPolicy: {{ .pullPolicy | quote }}
  command:
    - /fluent-bit/bin/fluent-bit
    - -c
    - /fluent-bit/etc/fluent-bit.conf
  securityContext:
    runAsUser: {{ .runAsUser }}
    runAsNonRoot: true
  ports:
    - name: http
      containerPort: {{ .httpPort }}
      protocol: TCP
  resources:
    requests:
      cpu: "5m"
      memory: "10Mi"
    limits:
      cpu: "50m"
      memory: "60Mi"
  env:
    - name: K8S_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: K8S_POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
  volumeMounts:
    - mountPath: {{ .logsDir }}
      name: scratch
      subPathExpr: "{{ .serviceName }}/logs"
    - mountPath: /fluent-bit/etc/
      name: {{ .configMapVolumeName }}
{{- end }}
{{- end -}}

{{- define "skyforge.forwardWorker.logForwarderConfig" -}}
{{- if .enabled }}
fluent-bit.conf: |
  [INPUT]
      Name              tail
      Tag               fwd.{{ .serviceTag }}.${K8S_NODE_NAME}
      Path              {{ .logsDir }}/{{ .serviceLogFile }}
      DB                {{ .logsDir }}/flb_{{ .serviceLogFile }}.db
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
