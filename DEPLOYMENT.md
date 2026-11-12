# Production deployment

The [Deploy paid site](https://github.com/c-o-s-m-e-t-i-c-s/g6-bi-dsa2/actions/workflows/paid-site.yml) workflow runs on pushes to `main`. It skips deployment until one of these is committed:

- `deploy/site/index.html` and the assets for a static site.
- `deploy/build.sh`, a Bash script that installs locked dependencies if needed, runs the project's tests and build, and writes the final static site to `deploy/site/`. It must exit with an error if a required check fails.

Include only files intended to be public in `deploy/site/`. Keep environment files, database files, credentials, and original datasets outside that directory. Use a backend deployment configuration if the project needs a server-side runtime or database connection. This workflow publishes static assets and does not run database migrations.

GitHub builds without AWS credentials. A separate job checks the archive, uploads it to private AWS storage using a short-lived role, and deploys through the project's fixed command on the shared EC2 host. The server checks the packaged identity and the site response before marking a release active. It restores the previous release on a failed activation and keeps the current and previous verified releases. Release archives expire after 30 days.

Check the job summary in Actions for skipped runs, errors, and the deployment command ID. To retry after correcting the source, push the fix to `main` or run the workflow again from `main`. For a rerun of an existing run, choose **Re-run all jobs** so the build and deploy jobs use the same attempt number. For a rollback after a successful deploy, revert the application change on `main` or ask the EC2 operator to restore the previous verified release.
