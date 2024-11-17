# Readme

Notes to remember as I use `sops` so infrequently.

- Set the `SOPS_AGE_KEY_FILE` environment variable to the path of the `age` keys file.

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

- Edit the `keystore.yaml` file to add new keys.

```bash
sops keystore.yaml
```

- Add a new host and update the keys.

```bash
# Edit and save the file.
sops keystore.yaml

# Update the keys for all secrets.
sops updatekeys keystore.yaml
```

- To obtain the `age` public key for a host, run the following command:

```bash
nix-shell -p ssh-to-age --run 'ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub >> ~/.config/sops/age/keys.txt'
```
