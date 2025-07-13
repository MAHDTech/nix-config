# Readme

AGS is the CLI for Astal.

## Steps

- Initialize the project in the current directory.

```bash
ags init --directory $(pwd)/ --force --gtk 4
```

- Make your changes

- Generate the types

```bash
ags types --directory $(pwd)/ --package
```

- Run the app to test

```bash
ags run --directory $(pwd)/
```
