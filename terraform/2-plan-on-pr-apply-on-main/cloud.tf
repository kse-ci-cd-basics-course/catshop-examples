# Keeping the state in a file next to the configuration is correct on your own
# machine and useless in CI: a runner is a fresh machine with an empty folder,
# so every job would start from nothing. plan would always say "everything is
# new", apply would always create, and nothing would ever be drift.
#
# `cloud` is `backend` with a different name. It gives three things the runner
# cannot: the state outlives the job, the lock is real, and there is a history.
terraform {
  cloud {
    organization = "REPLACE-WITH-YOUR-ORG"

    workspaces {
      name = "catshop-examples-pipeline"
    }
  }
}
