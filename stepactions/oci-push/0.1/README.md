# oci-push stepaction

This StepAction pushes the working directory contents to a specified OCI artifact repository tag. If the tag exists, it will update the existing content with the content of the working directory.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|workspace-path|Path to the workspace that is about to be uploaded to OCI artifact||true|
|credentials-volume-name|Name of the volume that mounts the secret with "oci-storage-dockerconfigjson" key containing registry credentials in .dockerconfigjson format||true|
|oci-ref|Full OCI artifact reference in a format "quay.io/org/repo:tag"||true|
|oci-tag-expiration|OCI artifact tag expiration|1y|false|