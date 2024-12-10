# leaktk-scan stepaction

This StepAction scans specified directory (workingDir) using [leaktk-scanner CLI](https://github.com/leaktk/scanner) and deletes files containing sensitive information (credentials, certificates) that shouldn't be exposed to public.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|workspace-path|Path to the workspace directory that is about to be scanned||true|