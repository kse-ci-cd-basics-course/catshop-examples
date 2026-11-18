# 3 · A real cloud

The same architecture as `1-the-minimum`, on Google Cloud. A load balancer, two instances
behind it, one managed database — and this time the state is in a bucket and the pipeline
holds no key at all.

| `1-the-minimum` | here |
|---|---|
| `docker_network` | a VPC, a subnet, and two firewall rules |
| `nginx` + `nginx.conf.tftpl` | a health check, a backend service, a URL map, a target proxy and a forwarding rule — **five objects to say "upstream" and "proxy_pass"** |
| `count = 2` on a container | a regional managed instance group with `target_size = 2`, which also replaces one that dies |
| a Postgres container | Cloud SQL on a private address, reached over a VPC peering |
| state in a hosted workspace | state in a GCS bucket you own |
| no credentials | OIDC, and still no stored credentials |

**This one costs money.** See the bottom.

## Once, before anything

### 1 · The bucket the state lives in

It cannot be created by the configuration whose state it holds, so it is made by hand and
then never again.

```bash
gcloud storage buckets create gs://$PROJECT-tfstate \
  --location=europe-west1 --uniform-bucket-level-access
gcloud storage buckets update gs://$PROJECT-tfstate --versioning
```

Versioning is the only way back from a truncated state file. Put the bucket name in
`backend.tf`.

### 2 · The trust, so the pipeline needs no key

```bash
PROJECT=your-project
NUM=$(gcloud projects describe $PROJECT --format='value(projectNumber)')
REPO=owner/repo

gcloud iam service-accounts create gha-deployer

gcloud iam workload-identity-pools create gh-pool --location=global

gcloud iam workload-identity-pools providers create-oidc github \
  --location=global --workload-identity-pool=gh-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository=='${REPO}'"

gcloud iam service-accounts add-iam-policy-binding \
  gha-deployer@$PROJECT.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$NUM/locations/global/workloadIdentityPools/gh-pool/attribute.repository/${REPO}"
```

> **`--attribute-condition` is not optional.** A provider created without it trusts
> *every* GitHub Actions workflow on the internet, because the issuer is the same one for
> all of them. Anyone could mint a token in their own repository and present it to your
> pool. The condition is what makes the trust yours, and the binding narrows it again to
> one repository — add `attribute.ref` to pin a branch as well.

Then set three repository **variables** (not secrets — none of these are sensitive):

```
GCP_PROJECT_ID       your-project
GCP_WIF_PROVIDER     projects/<NUM>/locations/global/workloadIdentityPools/gh-pool/providers/github
GCP_SERVICE_ACCOUNT  gha-deployer@your-project.iam.gserviceaccount.com
```

Grant the service account what it actually needs — `roles/storage.objectAdmin` on the state
bucket, plus the roles for what it creates. Start too small and read the errors; starting
with `roles/editor` teaches nothing and leaves a key to everything.

*(A scripted version of this bootstrap, with the same attribute conditions, is at
`github.com/amir-cloud-security/gcp-terraform-test-oidc`.)*

## Running it

Locally — your own `gcloud` credentials, the same state bucket:

```bash
gcloud auth application-default login
terraform init
terraform apply -var project_id=$PROJECT
curl -s "$(terraform output -raw url)/health"
```

In CI — `pull-request.yml` plans and comments, `main.yml` applies the saved plan behind an
environment gate. No key is stored in either. The job mints a token, Google trades it for
an hour's credentials, and nothing survives the run.

Both write to the same bucket, so the lock is real between them: apply locally while the
pipeline is applying and the second one waits.

## What takes the longest to believe

**The first apply answers 502 for several minutes.** The forwarding rule exists long before
the instances have pulled the image and `/health` has replied twice. Nothing is wrong; the
backends are simply unhealthy until they are not.

**Health checks do not come from the load balancer.** They come from `35.191.0.0/16` and
`130.211.0.0/22`, and if `network.tf` did not allow them every backend would be permanently
unhealthy with nothing useful in any log. It is the most common reason a correct-looking
load balancer serves nothing.

**The database has no public address.** Reaching a managed database privately needs a VPC
peering to Google's network — `google_compute_global_address` plus
`google_service_networking_connection`. Those two resources are invisible in every
architecture diagram and mandatory in every real one.

## Cost, honestly

Nothing here is in the always-free tier.

| | |
|---|---|
| external HTTP load balancer (forwarding rule + traffic) | ~$18/month |
| 2 × `e2-micro` | ~$12/month |
| Cloud SQL `db-f1-micro` | ~$8/month |
| Cloud NAT (router + gateway) | ~$33/month |
| **at rest, no traffic** | **~$70/month** |

Cloud NAT is the expensive surprise and it exists only because the instances have no public
address. Giving each one a public address instead is roughly $6/month and a worse idea.

```bash
terraform destroy -var project_id=$PROJECT
```

Do it. The load balancer bills whether or not anybody sends it a request.
