module "github_repository" {
  source  = "pagopa-dx/github-environment-bootstrap/github"
  version = "~> 1.0"

  repository = {
    name                   = "dx-automation"
    description            = "DX Repository for Automations"
    topics                 = []
    reviewers_teams        = []
    environments           = ["uat", "prod"]
  }
}
