# Upload Ginkgo Results to Sealights

This Tekton **StepAction** automates the process of uploading Ginkgo test results to Sealights. It handles the creation of a Sealights test session, processes a Ginkgo JSON report, uploads the test results, and cleans up resources by deleting the test session after the process is completed.

## Parameters

This StepAction supports the following parameters:

| **Parameter Name**       | **Type**  | **Default Value**      | **Description**                                                                                         |
|---------------------------|-----------|------------------------|---------------------------------------------------------------------------------------------------------|
| `sealights-domain`        | `string`  | `redhat.sealights.co`  | The domain name of the Sealights server.                                                               |
| `sealights-bsid`          | `string`  | `""`                   | The Sealights Build Session ID (BSID) associated with the build.                                       |
| `test-stage`              | `string`  |                        | The name or identifier of the testing phase (e.g., `integration`, `e2e`). Used for categorizing results.|
| `ginkgo-json-report-path` | `string`  |                        | The file path to the Ginkgo JSON report containing the test results.                                   |

---

## Environment Variables

The following environment variables are used in this StepAction. These are automatically populated from the provided parameters:

| **Environment Variable**      | **Populated From**       | **Description**                                                         |
|-------------------------------|--------------------------|-------------------------------------------------------------------------|
| `SEALIGHTS_DOMAIN`            | `sealights-domain`       | The domain name of the Sealights server.                               |
| `SEALIGHTS_BSID`              | `sealights-bsid`         | The Sealights Build Session ID (BSID).                                 |
| `GINKGO_JSON_REPORT_PATH`     | `ginkgo-json-report-path`| The file path to the Ginkgo JSON report.                               |
| `TEST_STAGE`                  | `test-stage`             | The name or identifier of the testing phase.                           |
| `SEALIGHTS_AGENT_TOKEN`       | From Kubernetes Secret   | The Sealights API token retrieved from the `sealights-credentials` secret. |

---

## Workflow

1. **Create Test Session**: The StepAction starts by creating a new test session in Sealights.
2. **Process Ginkgo JSON Report**: The Ginkgo test report is parsed, and test results are formatted into JSON.
3. **Upload Test Results**: The processed test results are uploaded to the created Sealights test session.
4. **Clean Up**: The test session is deleted.

---

## Example Usage

Here’s an example Tekton YAML configuration using this StepAction:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: upload-ginkgo-results-task
spec:
  steps:
    # Previous steps goes here
    - name: sealights-reporter
      onError: continue
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/sealights/upload-ginkgo-results/0.1/upload-ginkgo-results.yaml
      params:
        - name: ginkgo-json-report-path
          value: /workspace/artifact-dir/e2e-report.json
        - name: test-stage
          value: $(params.test-stage)
        - name: sealights-bsid
          value: $(params.sealights-bsid)
```
