{{ define "yamlParseRec" }}
{{- range $key, $value := .yaml }}
  {{- if kindIs "string" $value }}
  {{- if contains  "*" $value }}
    {{ $key }}: {{ $value | quote }}
  {{ else }}
    {{ $key }}: {{ $value }}
  {{- end }}
  {{- end }}
  {{- if kindIs "map" $value }}
    {{ $key }}:
      {{- include "yamlParseRec" (dict "yaml" $value ) | indent 2 }}
  {{- end }}
  {{- if kindIs "slice" $value }}
    {{ $key }}: 
    {{- range $item := $value }}
    {{- if kindIs "map" $item }}
      - {{ include "yamlParseRec" (dict "yaml" $item ) | trim | indent 4 | trim }}
    {{- else }}
      - {{ $item }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if kindIs "bool" $value }}
    {{ $key }}: {{ $value }}
  {{- end }}
  {{- if  kindIs "int" $value }}
    {{ $key }}: {{ $value }}
  {{- end }}
  {{- if  kindIs "float64" $value }}
    {{ $key }}: {{ $value }}
  {{- end }}
{{- end }}
{{- end }}
