# Production deployment

KC Hospital runs as a Flask service on the shared UST EC2 instance behind HTTPS at `kchospital.space` and `www.kchospital.space`. It uses the existing RDS schema `2026_3dsa_6_kchospital` through a TLS connection with a dedicated account. Staff passwords and application settings are stored privately on EC2.

The [Deploy web app](https://github.com/c-o-s-m-e-t-i-c-s/g6-bi-dsa2/actions/workflows/paid-site.yml) workflow runs on pushes to `main`. It installs the pinned Python dependencies, tests Flask against isolated MySQL 8.4, and packages only the application runtime. See [the app setup](deploy/site/README.md) for the one-time additive baseline and fictional demo data. Later reviewed migrations go in `deploy/migrations/`.

## MySQL migrations

Use UTF-8 with LF line endings. Each numbered pair contains one additive `CREATE TABLE`, `ALTER TABLE … ADD`, or `CREATE INDEX` statement and one verification query. Verification must return exactly `1` and check the intended object through `information_schema` with `table_schema = DATABASE()`. For example:

```sql
SELECT EXISTS (SELECT 1 FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'orders');
```

Review the exact committed pair before merging. Send the commit and migration filenames to the EC2 operator for independent approval of both file digests. GitHub tests the ordered pairs on an isolated MySQL 8.4 instance. Production uses a dedicated TLS account and runs only approved files against this project's RDS schema. Keep every applied pair intact in later releases. Keep warehouse loaders, seed scripts, imports, and ad hoc queries outside `deploy/migrations/`.

The SQL stage skips when there are no files. Before each new migration, the EC2 runner saves a private backup of this schema. It records the migration as applied only after the verification query passes. If execution is interrupted or verification fails, an operator must reconcile the recorded pending migration before retrying. Reverting application code leaves applied schema changes in place.

GitHub builds without AWS credentials. A separate job checks the archive, uploads it to private AWS storage using a short-lived role, and deploys through the project's fixed command on the shared EC2 host. The server checks the packaged identity and the site response before marking a release active. It restores the previous release on a failed activation and keeps the current and previous verified releases. Release archives expire after 30 days.

Check the job summary in Actions for skipped runs, errors, and the deployment command ID. To retry after correcting the source, push the fix to `main` or run the workflow again from `main`. For a rerun of an existing run, choose **Re-run all jobs** so the build and deploy jobs use the same attempt number. For a rollback after a successful deploy, revert the application change on `main` or ask the EC2 operator to restore the previous verified release.
