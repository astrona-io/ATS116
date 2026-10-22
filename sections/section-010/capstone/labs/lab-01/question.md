# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** The OpenBao HTTP API

## Scenario

The inventory team runs a nightly report. A CronJob named `inventory-report` in the namespace `apicapstone` logs in to OpenBao with the AppRole `report`, lists every secret under `secret/inventory/`, and prints each secret's fields. Since the move to OpenBao it has never produced a report. Its script is in the ConfigMap `report-script`; the AppRole role ID and secret ID are mounted from the Secret `report-approle`.

Run it by hand to see the failure:

```sh
kubectl -n apicapstone create job --from=cronjob/inventory-report report-run-1
kubectl -n apicapstone logs job/report-run-1
```

## Your task

Fix the script in the ConfigMap `report-script` so that a Job created from the CronJob completes and prints one line per secret (`api`, `billing` and `config`) with its fields, followed by `REPORT OK`.

## Constraints

- The script must keep logging in with the AppRole `report` from the mounted files. Do not put any token into the script, the ConfigMap or the CronJob.
- Do not change the AppRole `report` or its policy `inventory-lister`; they already allow everything the report needs.
- Do not change the CronJob's image or schedule.

## Done when

- A new Job created from `cronjob/inventory-report` completes.
- Its log has a line starting with `api: {`, `billing: {` and `config: {`, and the line `REPORT OK`.
- The script still logs in through `auth/approle/login`.
