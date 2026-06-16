{ pkgs, ... }:
{
  # Caddy Web Server Configuration
  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
      {
          debug
      }
      :80 {
          root * /mnt/hdd/tftpboot/

          # Handler for dynamic wallpapers
          handle /dynamic/wallpaper.ipxe {
              rewrite * /templates/wallpaper.tmpl
              header Content-Type text/plain
              templates {
                  between {{ }}
              }
              file_server
          }

          file_server browse

          handle_errors {
              respond "Error: Template render failed (500)" 500
          }

          log {
              output file /var/log/caddy/access.log
          }

          @binaries {
              path *.efi *.kpxe *.ipxe *.iso *.img
              path */kernel */initrd */initrd-* memdisk
              path */bzImage
              path /images/nixos/*
          }

          header @binaries {
              Content-Type "application/octet-stream"
              Content-Disposition "attachment"
              Cache-Control "no-cache"
          }
      }
    '';
  };
}
