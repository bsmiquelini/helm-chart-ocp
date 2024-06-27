{{- define "project.name" -}}
{{ required "The projectName is required" .Values.projectName }}
{{- end -}}

{{- define "project.namespace" -}}
{{ required "The namespace is required" .Values.namespace }}
{{- end -}}

{{- define "project.dockerRegistry" -}}
{{ .Values.dockerRegistry }}
{{- end -}}

{{- define "common.labels" -}}
{{- range $key, $value := .Values.commonLabels }}
  {{ $key }}: {{ $value | quote }}
{{- end -}}
{{- end -}}

{{- define "common.annotations" -}}
{{- range $key, $value := .Values.commonAnnotations }}
  {{ $key }}: {{ $value | quote }}
{{- end -}}
{{- end -}}

