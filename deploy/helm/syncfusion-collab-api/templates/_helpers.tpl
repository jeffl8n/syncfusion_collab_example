{{- define "syncfusion-collab-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "syncfusion-collab-api.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "syncfusion-collab-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "syncfusion-collab-api.labels" -}}
helm.sh/chart: {{ include "syncfusion-collab-api.chart" . }}
app.kubernetes.io/name: {{ include "syncfusion-collab-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "syncfusion-collab-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "syncfusion-collab-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "syncfusion-collab-api.licenseSecretName" -}}
{{- if .Values.licenseSecret.existing -}}
{{- .Values.licenseSecret.existing -}}
{{- else if .Values.licenseSecret.name -}}
{{- .Values.licenseSecret.name -}}
{{- else -}}
{{- printf "%s-license" (include "syncfusion-collab-api.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
