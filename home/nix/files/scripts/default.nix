{
  imports = [
    # General scripts.
    ./scripts.nix

    # Storj related scripts.
    ./storj.nix

    # Sync projects.
    ./sync-projects.nix

    # GitHub
    ./github.nix

    # Terraform
    ./terraform.nix

    # OpenTofu
    ./opentofu.nix

    # DaisyUI
    ./daisyui.nix

    # NixOS MCP
    ./mcp-nixos.nix
  ];
}
