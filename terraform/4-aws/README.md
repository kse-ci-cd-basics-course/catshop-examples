# 4 · The same thing on AWS

Reading material. Nothing here is applied — `init -backend=false` and `validate` run offline,
so the whole file can be checked without an account.

It is `../3-gcp` resource for resource. The point is where the two clouds stop agreeing.

```bash
terraform init -backend=false
terraform validate
```

## The network

| | Google | AWS |
|---|---|---|
| the VPC | **global** — one network, every region | **regional**, and two of them cannot see each other without peering |
| the subnet | **regional** — covers every zone | **zonal** — one per zone, declared by you |
| the firewall | a rule on the network, matched by **tag**; stateful | a **security group** on the interface (stateful) and optionally a **NACL** on the subnet (stateless) |
| the managed database | in Google's project, reached over a **VPC peering** | **in your own subnets**, via a DB subnet group |
| the way out for a private instance | Cloud NAT, one per region, ~$33/month | NAT Gateway, **one per zone**, ~$32/month each |

**The sentence that explains the rest: a Google subnet is regional and an AWS subnet is
zonal.** Everything else follows. It is why `network.tf` here declares *two* subnets and
`../3-gcp/network.tf` declares one, and why `aws_lb` has a `subnets` argument at all.

The NAT line is the one that costs real money in both directions. Highly available on AWS
means a gateway per zone, so ~$64/month before a byte moves. This file avoids it entirely
with public subnets and an internet gateway, which is free and is the right trade for
something you will destroy in an hour.

## The load balancer

One role, three vocabularies:

| | nginx | Google | AWS |
|---|---|---|---|
| the listener | `listen 80;` | forwarding rule **+** target proxy | `aws_lb_listener` |
| the pool | `upstream { server …; }` | backend service **+** instance group | `aws_lb_target_group` |
| the rule | `proxy_pass` | URL map | the listener's `default_action` |
| the health check | `max_fails` / `fail_timeout`, **passive** | a separate object, active, from `35.191.0.0/16` | on the **target group**, active, from the load balancer |
| objects to write | 1 file | **5** | **3** |

**The deepest difference is where the load balancer physically is.**

Google's is nowhere in your network — anycast at the edge, and you are handed one global IP.
That is why its health checks arrive from two fixed external ranges that your firewall has
to allow, and why it needs no subnet from you.

An AWS ALB has **network interfaces inside your own subnets**, one per zone. That is why it
needs two subnets to exist, why it answers on a DNS name instead of an address you own, and
why the health check comes from its own security group — see `aws_security_group.app`,
which allows port 8080 from `aws_security_group.lb` and from nothing else.

## Proving who you are

Same shape, different nouns, and the same catastrophic mistake available in both.

| | Google | AWS |
|---|---|---|
| the trust object | workload identity pool **+** OIDC provider | an IAM **OIDC identity provider** |
| what the job becomes | a **service account**, impersonated | an IAM **role**, assumed |
| the action | `google-github-actions/auth@v2` | `aws-actions/configure-aws-credentials@v4` |
| what pins it | `--attribute-condition` on the provider, then a `principalSet` binding | a `Condition` on `sts:AssumeRoleWithWebIdentity` matching `…:sub` |
| the hole | a provider with no attribute condition | `repo:your-org/*:*` |

Both issue short-lived credentials. Neither stores anything. And in both, the pin is the
entire security model: the issuer is the same `token.actions.githubusercontent.com` for
every GitHub Actions job on earth, so a trust without a condition on it trusts all of them.

The AWS trust policy, for comparison with `../3-gcp/README.md`:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:your-org/your-repo:ref:refs/heads/main"
    }
  }
}
```

Change that last line to `repo:your-org/*:*` and every repository you own can assume the
role. It is one character of carelessness and it reads as if it were deliberate.

## Cost, if it were applied

| | |
|---|---|
| Application Load Balancer | ~$18/month + LCUs |
| 2 × `t3.micro` | ~$15/month |
| RDS `db.t4g.micro` + 20GB | ~$13/month |
| **at rest** | **~$46/month** |

Cheaper than `../3-gcp` only because this one has no NAT gateway. Add one per zone for a
private-subnet design and AWS becomes the more expensive of the two.
