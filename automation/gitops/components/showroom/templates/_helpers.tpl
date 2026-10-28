{{- define "showroom.labels" -}}
demo.redhat.com/application: "lightwell-tssc-workshop"
app.kubernetes.io/name: showroom
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: lightwell-tssc-workshop
{{- end -}}

{{/*
Route host — showroom.<deployer.domain>
*/}}
{{- define "showroom.routeHost" -}}
{{- if .Values.deployer.domain -}}
{{ .Values.showroom.name }}.{{ .Values.deployer.domain }}
{{- else -}}
{{ .Values.showroom.name }}.apps.cluster.example.com
{{- end -}}
{{- end -}}

{{- define "showroom.url" -}}
https://{{ include "showroom.routeHost" . }}
{{- end -}}

{{- define "showroom.giteaHost" -}}
{{- if .Values.deployer.domain -}}
{{ .Values.lab.giteaHostPrefix }}.{{ .Values.deployer.domain }}
{{- else -}}
{{ .Values.lab.giteaHostPrefix }}.apps.cluster.example.com
{{- end -}}
{{- end -}}

{{- define "showroom.giteaUrl" -}}
https://{{ include "showroom.giteaHost" . }}
{{- end -}}

{{- define "showroom.destRegistryHost" -}}
{{- if .Values.deployer.domain -}}
registry-{{ .Values.lab.lightwellRepoNamespace }}.{{ .Values.deployer.domain }}
{{- else -}}
registry-{{ .Values.lab.lightwellRepoNamespace }}.apps.cluster.example.com
{{- end -}}
{{- end -}}

{{- define "showroom.destRegistryUrl" -}}
https://{{ include "showroom.destRegistryHost" . }}
{{- end -}}

{{- define "showroom.labClis" -}}
{{- $names := list -}}
{{- if and .Values.showroom.terminal.enabled .Values.showroom.terminal.tools.enabled }}
{{- range .Values.showroom.terminal.tools.items }}
{{- $names = append $names .name -}}
{{- end }}
{{- end }}
{{- join "," $names -}}
{{- end -}}
