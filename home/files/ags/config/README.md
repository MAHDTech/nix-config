# Readme

AGS is the CLI for Astal.

## Steps

- Initialize the project in the current directory.

```bash
ags init --directory $(pwd)/ --force
```

- Make your changes

- Generate the types

```bash
ags types --directory $(pwd)/ --tsconfig
```

- Run the app to test

```bash
ags run --directory $(pwd)/
```
