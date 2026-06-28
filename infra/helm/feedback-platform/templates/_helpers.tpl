{{/*
Return application name. Never return empty.
*/}}
{{- define "feedback-platform.apiName" -}}
{{- default "feedback-api" .Values.api.name -}}
{{- end -}}