_: {
  config.perSystem =
    { pkgs, ... }:
    {
      config.terranix.terranixConfigurations.github-tf = {
        workdir = ".terraform/github";
        terraformWrapper.package = pkgs.opentofu.withPlugins (p: [ p.integrations_github ]);
        modules = [
          {
            terraform.required_providers.github = {
              source = "integrations/github";
              version = "~> 6.0";
            };

            provider.github = {
              owner = "jtrrll";
              token = "\${var.github_token}";
            };

            variable = {
              github_token = {
                type = "string";
                sensitive = true;
                description = "GitHub personal access token with repo admin permissions";
              };
              deploy_ssh_key = {
                type = "string";
                sensitive = true;
                description = "SSH private key for deploying to servers";
              };
              pr_bot_token = {
                type = "string";
                sensitive = true;
                description = "GitHub PAT for the PR bot to create/merge PRs";
              };
            };

            resource = {
              github_repository.web = {
                name = "web";
                description = "jtrrll's personal corner of the web";
                visibility = "public";
                homepage_url = "https://www.jtrrll.com";

                has_issues = true;
                has_projects = false;
                has_wiki = false;
                has_discussions = false;

                allow_merge_commit = false;
                allow_squash_merge = true;
                allow_rebase_merge = false;
                allow_auto_merge = true;
                allow_update_branch = true;
                delete_branch_on_merge = true;

                topics = [
                  "nix"
                  "nixos"
                  "terranix"
                  "personal-website"
                ];
              };

              github_repository_vulnerability_alerts.web = {
                repository = "\${github_repository.web.name}";
              };

              github_branch_default.main = {
                repository = "\${github_repository.web.name}";
                branch = "main";
              };

              github_repository_ruleset.main = {
                name = "main";
                repository = "\${github_repository.web.name}";
                target = "branch";
                enforcement = "active";

                conditions = {
                  ref_name = {
                    include = [ "~DEFAULT_BRANCH" ];
                    exclude = [ ];
                  };
                };

                rules = {
                  deletion = true;
                  non_fast_forward = true;
                  required_linear_history = true;
                };
              };

              github_repository_ruleset.pull_requests = {
                name = "pull-requests";
                repository = "\${github_repository.web.name}";
                target = "branch";
                enforcement = "active";

                conditions = {
                  ref_name = {
                    include = [ "~ALL" ];
                    exclude = [ ];
                  };
                };

                rules = {
                  pull_request = {
                    dismiss_stale_reviews_on_push = false;
                    required_approving_review_count = 0;
                    require_last_push_approval = false;
                  };

                  required_status_checks = {
                    required_check = [
                      {
                        context = "Checks";
                      }
                      {
                        context = "Build";
                      }
                    ];
                    strict_required_status_checks_policy = true;
                  };
                };
              };

              github_actions_secret.deploy_ssh_key = {
                repository = "\${github_repository.web.name}";
                secret_name = "DEPLOY_SSH_KEY";
                value = "\${var.deploy_ssh_key}";
              };

              github_actions_secret.pr_bot_token = {
                repository = "\${github_repository.web.name}";
                secret_name = "PR_BOT_PERSONAL_ACCESS_TOKEN";
                value = "\${var.pr_bot_token}";
              };
            };

            output.url = {
              value = "\${github_repository.web.html_url}";
            };
          }
        ];
      };
    };
}
