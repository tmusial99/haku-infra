{{- define "app-of-apps.application" -}}
{{- $ := .root -}}
{{- $v := .vals -}}

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $v.name }}
  namespace: {{ $.Values.global.destination.namespace }}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  {{- if $v.syncWave }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ $v.syncWave | quote }}
    argocd.argoproj.io/compare-options: ServerSideDiff=true
  {{- end }}

spec:
  project: {{ $.Values.global.project }}
  source:
    {{- if $v.chart }}
    repoURL: {{ $v.chart.repoURL }}
    chart: {{ $v.chart.name }}
    targetRevision: {{ $v.chart.version }}
    {{- else if $v.path }}
    repoURL: {{ $.Values.global.repoURL }}
    targetRevision: {{ $.Values.global.targetRevision | quote }}
    path: {{ $v.path }}
    {{- end }}
    {{- if or $v.helmValues $v.helm }}
    helm:
      {{- if $v.helmValues }}
      values: |
        {{- toYaml $v.helmValues | nindent 8 }}
      {{- end }}
      {{- if and $v.helm $v.helm.valueFiles }}
      valueFiles:
        {{- range $vf := $v.helm.valueFiles }}
        - {{ $vf | quote }}
        {{- end }}
      {{- end }}
      {{- if and $v.helm $v.helm.values }}
      values: |
        {{- toYaml $v.helm.values | nindent 8 }}
      {{- end }}
    {{- end }}

  destination:
    server: {{ $.Values.global.destination.server | quote }}
    namespace: {{ $v.namespace }}

  syncPolicy:
    {{- toYaml $.Values.global.syncPolicy | nindent 4 }}
{{- end }}
