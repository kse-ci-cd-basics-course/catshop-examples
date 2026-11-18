# 2 · Plan on the pull request, apply on main

```bash
diff ../1-the-minimum/ci.yml pull-request.yml
```

`../1-the-minimum` applied straight from a push: nobody read anything, and a green tick was the only
thing the reviewer saw. Here the pull request **proposes** and main **applies**, and the
thing applied is the thing that was proposed.

**Files:** `pull-request.yml` · `main.yml` — and the same stack, unchanged.

## -out is the load-bearing flag

```bash
terraform plan -out=tfplan      # the proposal, as bytes
terraform apply tfplan          # those bytes, no re-planning
```

Without `-out`, `apply` computes a *new* plan against whatever the world looks like at apply
time — which is not what anybody reviewed. `apply tfplan` takes no `-auto-approve`, because
saving the plan was the approval.

The plan travels between the two jobs as an artifact. The `apply` job runs `init` again
because it is a different machine with an empty folder — the plan file crossed, the
`.terraform` directory did not.

## Where the review happens

`plan.txt` is posted as a pull request comment. Nobody opens an artifact; the comment is
already on the page the reviewer is reading. The artifact stays for the audit trail.

`-detailed-exitcode` gives `0` no changes, `1` error, `2` changes — which is why
`terraform_wrapper: false` is set on `setup-terraform`. The wrapper normalises exit codes
and this step reads them.

## The gate

The `apply` job declares `environment: production`. A required reviewer on that environment
is a person opening a gate, and the environment is also the only place real credentials
would ever be stored — so only that job could reach them.

## Expected

On the pull request:

```
Plan: 9 to add, 0 to change, 0 to destroy.
```

posted as a comment, nothing created. On merge, the same nine, applied once, behind the
gate.
