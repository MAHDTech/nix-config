{pkgs, ...}: {
  home.packages = with pkgs; [
    wasmedge
    wasmer
    lunatic
    wasmi
    # wasm3
  ];
}
