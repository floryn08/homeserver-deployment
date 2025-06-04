{{/*
Helper to retrieve and decode a key from a secret
*/}}
{{- define "secretValue" -}}
{{- $secret := lookup "v1" "Secret" .namespace .secretName }}
{{- if $secret }}
  {{- index $secret.data .key | b64dec }}
{{- else }}
  {{- printf "MISSING_SECRET_%s_%s" .secretName .key }}
{{- end }}
{{- end }}
