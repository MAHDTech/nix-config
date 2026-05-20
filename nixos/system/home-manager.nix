{
  inputs,
  username,
  globalUsername,
  system,
  globalStateVersion,
  name,
  lib,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit
        inputs
        globalUsername
        globalStateVersion
        username
        system
        ;
      inCI = false;
    }
    // (
      let
        # Dynamically find host-specific syncthing config if it exists
        syncthingPath = ../hosts/${lib.toLower name}/home-manager/syncthing.nix;
      in
      if builtins.pathExists syncthingPath then import syncthingPath else { }
    );

    users.${username} = {
      imports = [
        ../../home
        inputs.sops-nix.homeManagerModules.sops
        inputs.catppuccin.homeManagerModules.catppuccin
      ];
    };
  };
}
