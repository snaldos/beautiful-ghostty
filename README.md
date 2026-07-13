# Beautiful Ghostty

A cosmic Ghostty shader with perspective stars, radial meteors, a moving galaxy,
a geodesic black hole, and a matching cursor effect.

## Install

Requires **Ghostty 1.2.0 or newer**, **Bash**, and Linux.

```bash
git clone https://github.com/arnaldoflopes/beautiful-ghostty.git
cd beautiful-ghostty
./install.sh
```

The repository may be cloned anywhere.

The installer:

- finds your Ghostty config;
- creates a timestamped `.bak` backup;
- removes active `custom-shader` settings from that config;
- adds the Beautiful Ghostty shader chain with absolute paths;
- enables the combined Cosmos shader;
- selects the `quality` GPU profile;
- validates and reloads Ghostty.

For a custom config location:

```bash
./install.sh --config /path/to/config.ghostty
```

Rerun `./install.sh` after moving the repository.

## GPU profiles

```bash
./ghostty-shaders.sh set-profile eco
./ghostty-shaders.sh set-profile balanced
./ghostty-shaders.sh set-profile quality
./ghostty-shaders.sh set-profile ultra
```

`quality` is the default.

## Shader modes

Combined background and cursor:

```bash
./ghostty-shaders.sh set combined cosmos
```

Separate background and cursor:

```bash
./ghostty-shaders.sh set background cosmos
./ghostty-shaders.sh set cursor cosmic
```

Current state:

```bash
./ghostty-shaders.sh status
```

Disable a stage:

```bash
./ghostty-shaders.sh set cursor none
./ghostty-shaders.sh set background none
./ghostty-shaders.sh set combined none
```

## License

Beautiful Ghostty is released under the MIT License.

The geodesic black-hole renderer contains MIT-licensed work adapted from
[`s0xDk/ghostty-blackhole`](https://github.com/s0xDk/ghostty-blackhole).
See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
