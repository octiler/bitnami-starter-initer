#!/usr/bin/env zsh
set -e

readonly -A MAINTAINER=(
    [name]=octiler
    [email]=octiler@163.com
)

readonly -A PLACEHOLDERS=(
    [template_name]="<PLACEHOLDER_REGULAR_CHARTNAME>"
    [main_object_block]="<PLACEHOLDER_REGULAR_CHARTNAME>"
    [main_container_name]="<CHARTNAME>"
    [main_container]="<CHARTNAME>"
    [container_name]=app
    [port_name]="<PLACEHOLDER_PORT_NAME>"
    [config_file_name]="config.json"
    [image_name]="<CHARTNAME>"
    [image_tag]=notexist
    [component_name]="<CHARTNAME>"
    [IMAGE_REVISION]="-notexist"
    [OTHER_PARAMETERS_RELATED_TO_THIS_CONTAINER/POD]='miscellaneous: \{\}'
    [SECONDARY_OBJECT_BLOCK]="secondary_block"
    [OTHER_OBJECT_BLOCK]="other_block"
    [SAME_STRUCTURE_AS_THE_MAIN_CONTAINER/POD]='image: \{\"pullSecrets\": []\}'
    [SUBCHART_NAME]="subchart"
    [OTHER_PARAMETERS_RELATED_TO_THIS_SUBCHART]='image: \{\"pullSecrets\": []\}'
)

readonly -A BITNAMIS=(
    [BITNAMI_DEBUG]="<PLACEHOLDER_HATCHER>_DEBUG"
    [Bitnami]="<PLACEHOLDER_STARTERNAME>"
)

[[ -d $1 ]] || exit 1
cd $1

cat << EOF > Chart.yaml
apiVersion: v2
name: <CHARTNAME>
description: <DESCRIPTION>
type: application
version: 0.1.0
appVersion: "<APP_VERSION>"
icon: <ICON>
dependencies:
  - name: subchart
    repository: file://../subchart
    condition: subchart.enabled
    version: 1.X.X
  - name: common
    repository: oci://registry-1.docker.io/bitnamicharts
    # repository: file://../common
    # tags:
    #   - bitnami-common
    version: 2.x.x
maintainers:
  - name: ${MAINTAINER[name]}
    email: ${MAINTAINER[email]}
sources:
  - <SOURCE>
EOF

for pkey in ${(@k)PLACEHOLDERS};do
  find . \( \( -type d -name ".git" -prune \) -o -type f \) -not -name ".git" -exec \
    gsed -i'' -e "s#%%${(U)pkey}%%#${PLACEHOLDERS[${pkey}]}#g" {} \;
done

for bkey in ${(@k)BITNAMIS};do
  find . \( \( -type d -name ".git" -prune \) -o -type f \) -not -name ".git" -exec \
    gsed -i'' -e "s#${bkey}#${BITNAMIS[${bkey}]}#g" {} \;
done

find . \( \( -type d -name ".git" -prune \) -o -type f \) -not -name ".git" -exec \
  gsed -i'' -e "s#%%httpGet || command || etc%%#tcpSocket:\n              port: http#g" {} \;

gsed -i'' -e '/^# Copyright Broadcom, Inc. All Rights Reserved.$/d;/^# SPDX-License-Identifier: APACHE-2.0$/d' values.yaml
find . \( \( -type d -name ".git" -prune \) -o -type f \) -not -name ".git" -exec \
  gsed -i'' -e '/^{{\(- \)\?\/\*$/{N;N;N;N;/^{{\(- \)\?\/\*\nCopyright Broadcom, Inc. All Rights Reserved.\nSPDX-License-Identifier: APACHE-2.0\n\*\/}}\n$/d}' {} \;

cat << 'EOF' >> templates/_helpers.tpl

{{- define "<PLACEHOLDER_REGULAR_CHARTNAME>.config" -}}
{{- if .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.configTemplate -}}
  {{- merge (.Values.<PLACEHOLDER_REGULAR_CHARTNAME>.configuration | default dict) (.Files.Get .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.configTemplate | fromYaml )| toYaml }}
{{- else -}}
  {{- .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.configuration | toYaml }}
{{- end -}}
{{- end -}}

{{- define "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.auth-annotations" -}}
{{- if .Values.ingress.auth.enabled }}
nginx.ingress.kubernetes.io/auth-realm: Authentication Required
{{- if .Values.ingress.auth.existingSecret }}
nginx.ingress.kubernetes.io/auth-secret: {{ .Values.ingress.auth.existingSecret }}
{{- else }}
nginx.ingress.kubernetes.io/auth-secret: ingress-auth-{{ include "common.names.fullname" . }}
{{- end }}
nginx.ingress.kubernetes.io/auth-type: basic
{{- end -}}
{{- end -}}

{{- define "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.auth" -}}
{{- range . -}}
{{ htpasswd .username .password }}
{{ end -}}
{{- end -}}

{{- define "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.hostname" -}}
{{- if .Values.ingress.domain -}}
{{- default (printf "%s.%s" (include "common.names.fullname" .) .Values.ingress.domain) .Values.ingress.hostname -}}
{{- else -}}
{{- .Values.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{- define "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.extraHostname" -}}
{{- if .Values.ingress.extraDomain -}}
{{- default (printf "%s.%s" (include "common.names.fullname" .) .Values.ingress.extraDomain) .Values.ingress.extraHostname -}}
{{- else -}}
{{- .Values.ingress.extraHostname -}}
{{- end -}}
{{- end -}}
EOF

cat << 'EOF' > templates/ingress-auth-secret.yaml
{{- if and .Values.ingress.enabled .Values.ingress.auth.enabled }}
{{- if not .Values.ingress.auth.existingSecret }}
apiVersion: v1
kind: Secret
metadata:
  name: ingress-auth-{{ .Release.Name }}
type: Opaque
data:
  {{- if .Values.ingress.auth.secret }}
  auth: {{ .Values.ingress.auth.secret }}
  {{- else }}
  auth: {{ include "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.auth" .Values.ingress.auth.ciphers | b64enc }}
  {{- end }}
{{- end }}
{{- end }}
EOF

gsed -i'' -e '/if or .Values.ingress.annotations/s/}}/.Values.ingress.auth.enabled }}/' templates/ingress.yaml
gsed -i'' -e '/list .Values.ingress.annotations/s//list .Values.ingress.annotations (include "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.auth-annotations" . | fromYaml)/' templates/ingress.yaml

cat << 'EOF' | gsed -i'' -e '/range .Values.ingress.extraHosts/e cat' templates/ingress.yaml
    {{- if ( include "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.extraHostname" . ) }}
    - host: {{ include "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.extraHostname" . | quote }}
      http:
        paths:
          {{- if .Values.ingress.extraPaths }}
          {{- toYaml .Values.ingress.extraPaths | nindent 10 }}
          {{- end }}
          - path: {{ .Values.ingress.path }}
            {{- if eq "true" (include "common.ingress.supportsPathType" .) }}
            pathType: {{ .Values.ingress.pathType }}
            {{- end }}
            backend: {{- include "common.ingress.backend" (dict "serviceName" (include "common.names.fullname" .) "servicePort" "<PLACEHOLDER_PORT_NAME>" "context" $) | nindent 14 }}
    {{- end }}
EOF

gsed -i'' -e '/range .Values.ingress.extraHosts/{N;s/\.name/default (printf "%s.%s" (include "common.names.fullname" $) .domain) .hostname/}' templates/ingress.yaml

gsed -i'' -e '/\$ingressNSMatchLabels/s//.Values.networkPolicy.ingressNSMatchLabels/;/\$ingressNSPodMatchLabels/s//.Values.networkPolicy.ingressNSPodMatchLabels/' templates/networkpolicy.yaml

gsed -i'' -e '/<PLACEHOLDER_HATCHER>_DEBUG/{N;s/\.Values\.image\.debug/.Values.<PLACEHOLDER_REGULAR_CHARTNAME>.image.debug/}' templates/statefulset.yaml
gsed -i'' -e '/<PLACEHOLDER_HATCHER>_DEBUG/{N;s/\.Values\.image\.debug/.Values.<PLACEHOLDER_REGULAR_CHARTNAME>.image.debug/}' templates/daemonset.yaml

gsed -i'' -e '/%%commands%%/s//commands/' templates/statefulset.yaml
gsed -i'' -e '/%%commands%%/s//commands/' templates/daemonset.yaml

gsed -i'' -e '/ \{10\}env:$/{N;N;N;N;s/\n \{12\}- name: foo\n \{14\}value: bar$//}' templates/deployment.yaml
gsed -i'' -e '/ \{10\}env:$/{N;N;N;N;s/\n \{12\}- name: foo\n \{14\}value: bar$//}' templates/statefulset.yaml
gsed -i'' -e '/ \{10\}env:$/{N;N;N;N;s/\n \{12\}- name: foo\n \{14\}value: bar$//}' templates/daemonset.yaml

gsed -i'' -e '/protocol:/s/\w*$/TCP/' templates/service.yaml

cat << 'EOF' | gsed -i'' -e '/^<PLACEHOLDER_REGULAR_CHARTNAME>:$/r /dev/stdin' values.yaml
  workload: ""
  workloads:
    deployment: false
    statefulset: false
    daemonset: false
EOF

cat << 'EOF' | gsed -i'' -e '1e cat' templates/deployment.yaml
{{- if or ( .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.workloads.deployment ) ( eq "deployment" .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.workload ) }}
EOF
cat << 'EOF' | gsed -i'' -e '$r /dev/stdin' templates/deployment.yaml
{{- end }}
EOF

cat << 'EOF' | gsed -i'' -e '1e cat' templates/statefulset.yaml
{{- if or ( .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.workloads.statefulset ) ( eq "statefulset" .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.workload ) }}
EOF
cat << 'EOF' | gsed -i'' -e '$r /dev/stdin' templates/statefulset.yaml
{{- end }}
EOF

cat << 'EOF' | gsed -i'' -e '1e cat' templates/daemonset.yaml
{{- if or ( .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.workloads.daemonset ) ( eq "daemonset" .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.workload ) }}
EOF
cat << 'EOF' | gsed -i'' -e '$r /dev/stdin' templates/daemonset.yaml
{{- end }}
EOF

gsed -i'' -e '/initialDelaySeconds:/s/\w*$/10/;/periodSeconds:/s/\w*$/10/;/timeoutSeconds:/s/\w*$/1/;/failureThreshold:/s/\w*$/10/;/successThreshold:/s/\w*$/1/;' values.yaml

gsed -i'' -e '/repository: bitnami\//s/bitnami/octiler/' values.yaml
gsed -i'' -e '/mountPath: \/bitnami\//s#/bitnami/<PLACEHOLDER_REGULAR_CHARTNAME>##' values.yaml

gsed -i'' -e '/^  podSecurityContext:$/{N;/enabled:/s/true/false/}' values.yaml
gsed -i'' -e '/^  containerSecurityContext:$/{N;/enabled:/s/true/false/}' values.yaml
gsed -i'' -e '/^  pdb:$/{N;/create:/s/true/false/}' values.yaml
gsed -i'' -e '/^persistence:$/{N;N;N;/enabled:/s/true/false/}' values.yaml
gsed -i'' -e '/^networkPolicy:$/{N;N;N;/enabled:/s/true/false/}' values.yaml
gsed -i'' -e '/^serviceAccount:$/{N;N;N;/create:/s/true/false/}' values.yaml
gsed -i'' -e '/^service:$/{N;N;N;/type:/s/LoadBalancer/ClusterIP/}' values.yaml

cat << 'EOF' | gsed -i'' -e '/^service:$/r /dev/stdin' values.yaml
  enabled: false
EOF
cat << 'EOF' | gsed -i'' -e '1e cat' templates/service.yaml
{{- if or .Values.service.enabled .Values.ingress.enabled }}
EOF
cat << 'EOF' | gsed -i'' -e '$r /dev/stdin' templates/service.yaml
{{- end }}
EOF

cat << 'EOF' | gsed -i'' -e '/^ingress:$/r /dev/stdin' values.yaml
  auth:
    enabled: false
    existingSecret: ""
    ## echo -n username:`echo "password" | openssl passwd -apr1 -salt octiler -stdin` | base64
    secret: ""
    ciphers: []
    # ciphers:
    #   - username: username
    #     password: password
  domain: ""
  extraDomain: ""
  extraHostname: ""
  pathType: Prefix
EOF
# gsed -i'' -e '/^  hostname:/s/<PLACEHOLDER_STARTER>/<CHARTNAME>/' values.yaml
gsed -i'' -e '/^  hostname:/s/[^[:space:]]*$/""/' values.yaml
gsed -i'' -e '/^  pathType:/s/ImplementationSpecific/Prefix/' values.yaml

touch config.yaml
cat << 'EOF' | gsed -i'' -e '/^  existingConfigmap:$/r /dev/stdin' values.yaml
  configTemplate: config.yaml
  configuration: {}
  config: ""
EOF

cat << 'EOF' | gsed -i'' -e '1e cat' templates/configmap.yaml
{{- if and (or .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.config .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.configuration) (not .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.existingConfigmap) }}
EOF
gsed -i'' -e '${/^  # Config file$/d}' templates/configmap.yaml
cat << 'EOF' | gsed -i'' -e '$r /dev/stdin' templates/configmap.yaml
    {{- if .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.config }}
    {{- include "common.tplvalues.render" ( dict "value" .Values.<PLACEHOLDER_REGULAR_CHARTNAME>.config "context" $ ) | nindent 4 }}
    {{- else }}
    {{- include "<PLACEHOLDER_REGULAR_CHARTNAME>.config" . | fromYaml | toPrettyJson | nindent 4 }}
    {{- end }}
{{- end }}
EOF

cat << 'EOF' | gsed -i'' -e '/^ \{12\}- name: empty-dir/e cat' templates/deployment.yaml
            - name: config
              mountPath: /config
              readOnly: true
EOF

cat << 'EOF' | gsed -i'' -e '/^ \{8\}- name: empty-dir/e cat' templates/deployment.yaml
        - name: config
          configMap:
            name: {{ include "common.names.fullname" . }}
            defaultMode: 0400
EOF

gsed -i'' -e '/servicePort/s/http/<PLACEHOLDER_PORT_NAME>/' templates/ingress.yaml
gsed -i'' -e '/\.Values\.ingress\.hostname/s//( include "<PLACEHOLDER_REGULAR_CHARTNAME>.ingress.hostname" . )/' templates/ingress.yaml

cat << 'EOF' | gsed -i'' -e '/^## %%SECONDARY_CONTAINER\/POD_DESCRIPTION%%$/e cat' values.yaml
clusterRoleBinding:
  create: false

EOF

cat << 'EOF' | gsed -i'' -e '1e cat' templates/clusterrolebinding.yaml
{{- if .Values.clusterRoleBinding.create }}
EOF
cat << 'EOF' | gsed -i'' -e '$r /dev/stdin' templates/clusterrolebinding.yaml
{{- end }}
EOF

rm templates/secret.yaml
rm templates/NOTES.txt

