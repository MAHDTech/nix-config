{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs; [xdg-user-dirs xdg-utils]; #++ unstablePkgs;

  xdg = {
    configFile = {
      # GitHub Label "pineapple"
      "github-label-pineapple" = {
        target = "github/labels/pineapple.json";
        text = ''
          {
              "name": ":pineapple:",
              "color": "f6fc49",
              "description": "BOHICA"
          }
        '';
      };

      # GitHub GraphQL mutation packages.
      "github-graphql-mutation-packages" = {
        target = "github/graphql/mutations/packages.gql";
        text = ''
          {
            mutation {
              deletePackageVersion(input: { packageVersionId: "$PACKAGE_VERSION_ID" }) {
                success
              }
            }
          }
        '';
      };

      # GitHub GraphQL query packages.
      "github-graphql-query-packages" = {
        target = "github/graphql/queries/packages.gql";
        text = ''
          {
            repository(owner: "$GITHUB_ORG", name: "$GITHUB_REPO") {
              packages(first: 100) {
                nodes {
                  id
                  name
                  packageType
                  versions(first: 100) {
                    nodes {
                      id
                      version
                      files(first: 10) {
                        nodes {
                          name
                          updatedAt
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
        '';
      };

      # GitHub GraphQL query projects.
      "github-graphql-query-projects" = {
        target = "github/graphql/queries/projects.gql";
        text = ''
          {
            search(type: REPOSITORY, query: "org:$GITHUB_ORG $GITHUB_REPO", first: 1) {
              edges {
                node {
                  __typename
                  ... on Repository {
                    owner {
                      id
                    }
                    name
                    projects(first: 10) {
                      edges {
                        node {
                          number
                          name
                          columns(first: 30) {
                            edges {
                              node {
                                name
                                cards(first: 30) {
                                  edges {
                                    cursor
                                    node {
                                      id
                                      note
                                      state
                                      content {
                                        ... on Issue {
                                          id
                                          number
                                          title
                                        }
                                        ... on PullRequest {
                                          id
                                          number
                                          title
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          }
        '';
      };
    };
  };
}
