{{/*
Chart name.
*/}}
{{- define "openuem.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name (release-prefixed).
*/}}
{{- define "openuem.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "openuem.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "openuem.labels" -}}
helm.sh/chart: {{ include "openuem.chart" . }}
{{ include "openuem.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "openuem.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openuem.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "openuem.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openuem.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Certificate PVC name (fixed, not release-prefixed).
*/}}
{{- define "openuem.certsPvcName" -}}
{{- .Values.certInit.persistence.claimName | default "openuem-certs" }}
{{- end }}

{{/*
Certificate mount path used by all pods.
*/}}
{{- define "openuem.certsMountPath" -}}
/etc/openuem-certs
{{- end }}

{{/*
DATABASE_URL — inline PostgreSQL or external database.
*/}}
{{- define "openuem.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgres://%s:%s@%s-postgresql:%d/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "openuem.fullname" .) (int .Values.postgresql.port) .Values.postgresql.auth.database }}
{{- else if .Values.externalDatabase.url }}
{{- .Values.externalDatabase.url }}
{{- else }}
{{- printf "postgres://%s:%s@%s:%d/%s" .Values.externalDatabase.username .Values.externalDatabase.password .Values.externalDatabase.host (int .Values.externalDatabase.port) .Values.externalDatabase.database }}
{{- end }}
{{- end }}

{{/*
NATS_SERVERS connection string.
*/}}
{{- define "openuem.natsServers" -}}
{{- $host := include "openuem.natsHostname" . }}
{{- printf "%s:%d" $host (int .Values.natsConfig.port) }}
{{- end }}

{{/*
OCSP URL.
*/}}
{{- define "openuem.ocspUrl" -}}
{{- $host := include "openuem.ocspHostname" . }}
{{- printf "http://%s:%d" $host (int .Values.ocspResponder.port) }}
{{- end }}

{{/*
OCSP responder hostname.
*/}}
{{- define "openuem.ocspHostname" -}}
{{- if .Values.ocspResponder.hostname }}
{{- .Values.ocspResponder.hostname }}
{{- else }}
{{- printf "%s-ocsp-responder" (include "openuem.fullname" .) }}
{{- end }}
{{- end }}

{{/*
NATS hostname.
Note: NATS subchart uses <releaseName>-nats, not <fullname>-nats.
*/}}
{{- define "openuem.natsHostname" -}}
{{- if .Values.natsConfig.hostname }}
{{- .Values.natsConfig.hostname }}
{{- else }}
{{- printf "%s-nats" .Release.Name }}
{{- end }}
{{- end }}

{{/*
Console hostname.
*/}}
{{- define "openuem.consoleHostname" -}}
{{- if .Values.console.hostname }}
{{- .Values.console.hostname }}
{{- else }}
{{- printf "console.%s" .Values.organization.domain }}
{{- end }}
{{- end }}

{{/*
PostgreSQL service name.
*/}}
{{- define "openuem.postgresqlServiceName" -}}
{{- printf "%s-postgresql" (include "openuem.fullname" .) }}
{{- end }}

{{/*
wait-for-certs initContainer (reusable across all deployments).
*/}}
{{- define "openuem.initWaitForCerts" -}}
- name: wait-for-certs
  image: busybox:1.36
  command: ["/bin/sh", "-c"]
  args:
    - |
      while [ ! -f {{ include "openuem.certsMountPath" . }}/certificates/ca/ca.cer ]; do
        echo "Waiting for certificates..."
        sleep 5
      done
  volumeMounts:
    - name: openuem-certs
      mountPath: {{ include "openuem.certsMountPath" . }}
      readOnly: true
{{- end }}

{{/*
openuem-certs volume definition (reusable across all deployments).
*/}}
{{- define "openuem.certsVolume" -}}
- name: openuem-certs
  persistentVolumeClaim:
    claimName: {{ include "openuem.certsPvcName" . }}
    readOnly: true
{{- end }}

{{/*
Secret name for PostgreSQL credentials (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB).
*/}}
{{- define "openuem.postgresqlSecretName" -}}
{{- if .Values.postgresql.auth.existingSecret }}
{{- .Values.postgresql.auth.existingSecret }}
{{- else }}
{{- printf "%s-secret" (include "openuem.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Secret name for DATABASE_URL.
*/}}
{{- define "openuem.databaseSecretName" -}}
{{- if .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecret }}
{{- else }}
{{- printf "%s-secret" (include "openuem.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Secret name for JWT_KEY.
*/}}
{{- define "openuem.consoleSecretName" -}}
{{- if .Values.console.existingSecret }}
{{- .Values.console.existingSecret }}
{{- else }}
{{- printf "%s-secret" (include "openuem.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Global image registry prefix.
*/}}
{{- define "openuem.imageRegistry" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/" .Values.global.imageRegistry }}
{{- end }}
{{- end }}
