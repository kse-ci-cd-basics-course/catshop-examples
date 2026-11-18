# tflint is not `terraform validate`. validate asks "is this valid HCL that the
# provider will accept"; tflint asks "is this a good idea" — unused variables,
# unpinned sources, deprecated syntax, provider-specific mistakes.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
