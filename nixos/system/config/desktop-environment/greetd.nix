##################################################
# Login Manager: greetd + tuigreet
##################################################

# NOTES:
# - Desktop-environment agnostic. tuigreet enumerates whatever wayland
#   sessions are registered, so it works regardless of which DE is enabled.
# - https://man.sr.ht/~kennylevinsen/greetd/

{
  pkgs,
  config,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    tuigreet
  ];

  # Greeter (Terminal)
  services.greetd = {
    enable = true;
    restart = true;

    settings = {
      default_session = {
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
          --asterisks \
          --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions \
          --greet-align center \
          --greeting "Welcome to Salt Labs Cloud" \
          --power-reboot 'shutdown -r now' \
          --power-shutdown 'shutdown -h now' \
          --remember \
          --remember-session \
          --time \
          --time-format '%I:%M %p | %a • %h | %F' \
          --width 100 \
          --theme border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red
        '';
        user = "greeter";
      };
    };
  };
}
