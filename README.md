# Current AI Infrastructure Repository

This repository contains the Helm charts and Argo CD application definitions for our services.

## Adding a New Containerized Service

1. **Add a Helm Chart**: Place or define your Helm chart in the [charts/](file:///home/jungle/infra/charts) directory.
2. **Create an Argo CD App**: Define an Argo CD Application resource under the [argo/](file:///home/jungle/infra/argo) directory.
3. **Set the Values**: Configure your service values within the application definition.

## Deployment Flow & Clusters

All changes pushed to this repository are automatically deployed to their respective clusters:

* **Staging Cluster**: Deployments target the staging cluster and read from the `dev` branch.
* **Production Cluster**: Deployments target the production cluster and read from the `main` branch.

## Ingress & Load Balancing

* Create a separate **Ingress** resource for each new application.
* All applications share a single common **Load Balancer**.

## Monitoring Status

To view the deployment status and sync states, visit:
👉 **[argo.ai-staging.chat](https://argo.ai-staging.chat)**

## Git Workflow

To make changes or add something new:

1. **Feature/Fix Branch**: Create a branch or fork from the `dev` branch and make your changes.
2. **Pull Request to Dev**: Submit a PR back to the `dev` branch and merge. This automatically deploys the changes to the **Staging Cluster**.
3. **QA & Release**: Once QA verification passes, merge the `dev` branch into the `main` branch to release the changes to the **Production Cluster**.

Secrets must come in via ESO - doppler single secret - staging and prod name /project-name
cloudflare connection to load balancer
Need to set up DNS
S3 and Postgres need terraform