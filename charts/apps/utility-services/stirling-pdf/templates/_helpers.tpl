{{- define "secretValue" -}}
{{- $secret := lookup "v1" "Secret" .namespace .secretName }}
{{- if not $secret }}
  {{- fail (printf "Missing secret: %s in namespace %s" .secretName .namespace) }}
{{- end }}
{{- index $secret.data .key | b64dec }}
{{- end }}
