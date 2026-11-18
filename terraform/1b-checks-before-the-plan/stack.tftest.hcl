# `terraform test` (1.6+). Each `run` block is a plan or an apply with its own
# variables, and the assertions read the resources that plan produced.
#
# These are plan-only, so nothing is created and nothing is billed — the point
# is to check that the CONFIGURATION behaves, not that the cloud does.

variables {
  docker_host = "unix:///var/run/docker.sock"
  name        = "catshop-test"
  port        = 18080
}

run "the_default_is_two_backends" {
  command = plan

  assert {
    condition     = length(docker_container.app) == 2
    error_message = "the default must be two replicas: one copy is not redundancy"
  }
}

# The claim the template makes is that the pool FOLLOWS the count. The only way
# to check that without applying is to plan it twice with different counts.
run "the_pool_follows_the_count" {
  command = plan

  variables {
    replicas = 3
  }

  assert {
    condition     = length(docker_container.app) == 3
    error_message = "raising replicas must add a container"
  }

  # `upload` is a SET of blocks, and a set has no index — so this walks it with
  # a for expression instead of reaching for [0].
  assert {
    condition = anytrue([
      for u in docker_container.lb.upload :
      length(regexall("catshop-test-app-2", u.content)) > 0
    ])
    error_message = "the third replica is not in the rendered nginx pool — the template names its backends by hand"
  }
}

# A validation rule nobody tests is a comment. This asserts the guard rail
# actually fires.
run "one_replica_is_rejected" {
  command = plan

  variables {
    replicas = 1
  }

  expect_failures = [var.replicas]
}
