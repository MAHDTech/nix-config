##################################################
# Name: github-runner
# Description: Reusable GitHub Actions self-hosted runner fleet.
#
# Wraps the upstream services.github-runners module so any host can
# declare one or more runners with a single enable flag. The runner
# registration PAT is delivered via opnix (1Password), consistent with
# the rest of the SOE — the host only needs /etc/opnix-token.
#
# Scope is expressed purely through the URL and all three levels work:
#   https://github.com/enterprises/<slug>  -> enterprise
#   https://github.com/<org>               -> organisation
#   https://github.com/<owner>/<repo>      -> repository
#
# Registration tokens expire after 1 hour, so the 1Password item must
# hold a PAT (classic scopes: manage_runners:enterprise, admin:org or
# repo depending on the registration level); the runner service then
# mints fresh registration tokens itself.
#
# Trust model: runners are trusted by default (nix + git + docker; the
# docker socket is root-equivalent). Set trusted = false on any runner
# that may serve public repos or fork PRs — it loses docker access, is
# forced ephemeral and keeps only the minimal toolset.
##################################################
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.github-runner-fleet;

  hostName = lib.toLower config.networking.hostName;

  # Derive registration scope from the URL so runner names are
  # self-describing: <hostname>-<scope>-<slug>
  scopeOf =
    url:
    let
      parts = lib.filter (p: p != "") (lib.splitString "/" (lib.removePrefix "https://github.com/" url));
    in
    if parts == [ ] then
      null
    else if lib.head parts == "enterprises" then
      (
        if lib.length parts == 2 then
          {
            type = "enterprise";
            slug = lib.elemAt parts 1;
          }
        else
          null
      )
    else if lib.length parts == 1 then
      {
        type = "org";
        slug = lib.head parts;
      }
    else if lib.length parts == 2 then
      {
        type = "repo";
        slug = lib.elemAt parts 1;
      }
    else
      null;

  runnerName =
    runner:
    if runner.name != null then
      runner.name
    else
      lib.toLower "${hostName}-${(scopeOf runner.url).type}-${(scopeOf runner.url).slug}";

  secretPath = name: "/run/secrets/github-runner/${name}";

  # opnix requires camelCase secret keys: jons-enterprise-x -> JonsEnterpriseX
  camelize =
    name:
    lib.concatMapStrings (part: lib.toUpper (lib.substring 0 1 part) + lib.substring 1 (-1) part) (
      lib.splitString "-" name
    );

  # Enough for checkout + nix builds out of the box.
  basePackages =
    with pkgs;
    [
      bash
      coreutils
      curl
      git
      gnutar
      gzip
      jq
      openssh
    ]
    ++ [ config.nix.package ];

  runnerType = lib.types.submodule {
    options = {
      url = lib.mkOption {
        type = lib.types.str;
        example = "https://github.com/enterprises/mahdtech";
        description = ''
          Registration URL. Determines the scope: an enterprise
          (github.com/enterprises/<slug>), an organisation
          (github.com/<org>) or a repository (github.com/<owner>/<repo>).
        '';
      };

      tokenReference = lib.mkOption {
        type = lib.types.str;
        default = cfg.tokenReference;
        defaultText = lib.literalExpression "config.services.github-runner-fleet.tokenReference";
        description = "1Password reference to the PAT used to register this runner.";
      };

      trusted = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Trusted runners get docker socket access (root-equivalent) and
          their extraPackages. Set to false for runners that may execute
          untrusted workflows (public repos, fork PRs): docker is
          removed, ephemeral is forced and only the base toolset remains.
        '';
      };

      runnerGroup = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "Default";
        description = "Runner group to register into (enterprise/org scopes).";
      };

      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override the derived <hostname>-<scope>-<slug> runner name.";
      };

      ephemeral = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Deregister and clean the runner after every job.";
      };

      extraLabels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "gpu" ];
        description = "Labels in addition to the defaults (nixos, hostname).";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Extra packages in the job PATH (trusted runners only).";
      };
    };
  };
in
{
  options.services.github-runner-fleet = {
    enable = lib.mkEnableOption "GitHub Actions self-hosted runners on this host";

    tokenReference = lib.mkOption {
      type = lib.types.str;
      default = "op://fleet/GitHub Runner/credential";
      description = "Default 1Password reference to the registration PAT.";
    };

    runners = lib.mkOption {
      type = lib.types.attrsOf runnerType;
      default = { };
      example = lib.literalExpression ''
        {
          enterprise.url = "https://github.com/enterprises/mahdtech";
          lab = {
            url = "https://github.com/bingamon-lab";
            trusted = false;
          };
        }
      '';
      description = "Runners to register from this host.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (attr: runner: {
        assertion = scopeOf runner.url != null;
        message = ''
          services.github-runner-fleet.runners.${attr}.url ("${runner.url}") is not a
          valid GitHub URL. Expected https://github.com/enterprises/<slug>,
          https://github.com/<org> or https://github.com/<owner>/<repo>.
        '';
      }) cfg.runners
      ++ [
        {
          assertion =
            lib.any (r: r.trusted) (lib.attrValues cfg.runners) -> config.virtualisation.docker.enable;
          message = ''
            services.github-runner-fleet: trusted runners require
            virtualisation.docker.enable = true (or set trusted = false).
          '';
        }
      ];

    services.github-runners = lib.mapAttrs' (
      _: runner:
      let
        name = runnerName runner;
      in
      lib.nameValuePair name {
        enable = true;

        inherit (runner) url runnerGroup;
        inherit name;

        # Untrusted runners must never carry state between jobs.
        ephemeral = runner.ephemeral || !runner.trusted;

        # Reclaim the name when a rebuilt host re-registers.
        replace = true;

        tokenFile = secretPath name;

        extraLabels = [
          "nixos"
          hostName
        ]
        ++ runner.extraLabels;

        extraPackages =
          basePackages ++ lib.optionals runner.trusted ([ pkgs.docker ] ++ runner.extraPackages);

        serviceOverrides = lib.optionalAttrs runner.trusted {
          SupplementaryGroups = [ "docker" ];
        };
      }
    ) cfg.runners;

    # Deliver each runner's PAT via opnix and bounce the runner when the
    # token rotates (a token change triggers re-registration on start).
    services.onepassword-secrets.secrets = lib.mapAttrs' (
      _: runner:
      let
        name = runnerName runner;
      in
      lib.nameValuePair "githubRunner${camelize name}" {
        reference = runner.tokenReference;
        path = secretPath name;
        owner = "root";
        group = "root";
        mode = "0400";
        services = [ "github-runner-${name}" ];
      }
    ) cfg.runners;
  };
}
