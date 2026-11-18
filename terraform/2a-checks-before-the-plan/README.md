# 2a · The checks in front of the plan

**This is a branch, not the next step.** It is `../2-plan-on-pr-apply-on-main` with three
more rungs on the ladder. Read that one first.

```bash
diff ../2-plan-on-pr-apply-on-main/pull-request.yml pull-request.yml
```

**Files added:** `.tflint.hcl` · `stack.tftest.hcl`

## Cheapest check first

| | Catches |
|---|---|
| `terraform fmt -check` | formatting. Cannot fail interestingly, so it runs first and costs nothing |
| `terraform validate` | is this valid HCL the provider will accept |
| `tflint` | is this a *good idea* — unused variables, unpinned sources, deprecated syntax |
| `terraform test` | does the configuration **behave** |

`validate` and `tflint` are different questions. A file can be perfectly valid and still
declare a variable nobody reads, or pin nothing.

## terraform test

`stack.tftest.hcl` is plan-only: three `run` blocks, nothing created, nothing billed.

```
run "the_default_is_two_backends"... pass
run "the_pool_follows_the_count"... pass
run "one_replica_is_rejected"... pass

Success! 3 passed, 0 failed.
```

Measured on Terraform 1.9.8, 18 Nov 2026.

The middle one is the interesting assertion. The configuration *claims* the nginx pool
follows `var.replicas`; the only way to check that without applying is to plan twice with
different counts and look at the rendered template:

```hcl
condition = anytrue([
  for u in docker_container.lb.upload :
  length(regexall("catshop-test-app-2", u.content)) > 0
])
```

`upload` is a **set** of blocks, and a set has no index — `upload[0]` fails with *Cannot
index a set value*. That error is the first thing anyone writing this hits.

The third asserts the `validation` block on `var.replicas` actually fires. A validation rule
nobody tests is a comment.
