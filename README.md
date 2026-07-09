# gramps-web-nix

Nix flake packaging [Gramps Web](https://www.grampsweb.org/) — a self-hosted, browser-based genealogy application ([gramps-project/gramps-web](https://github.com/gramps-project/gramps-web) frontend + [gramps-web-api](https://github.com/gramps-project/gramps-web-api) backend) — as native NixOS services (no Docker, no runtime `pip`).

Provides:
- `packages.gramps-web` — the grampsjs frontend (built with `buildNpmPackage` → `share/gramps-web/static`)
- `packages.gramps-web-api` — the Flask/Celery backend as a `python3Packages` derivation
- `nixosModules.gramps-web` — a NixOS module running gunicorn + a Celery worker
- `overlays.default` — exposes `pkgs.gramps-web` and the Gramps Web python packages

The derivations are carried from the (still-unmerged) nixpkgs PR [#417806](https://github.com/NixOS/nixpkgs/pull/417806) by TomaSajt, built against the consumer's own `nixpkgs`. When that PR lands, this flake becomes a thin wrapper over `pkgs.gramps-web` / `pkgs.python3Packages.gramps-web-api`.

**Deviations from upstream PR #417806** (see `pkgs/python-set.nix` and `pkgs/gramps-web-api/default.nix`):
- **AI extras dropped** — `accelerate`/`openai`/`sentence-transformers` (PyTorch) are removed; Gramps Web runs fine without semantic search / chat and PyTorch is far too heavy for a small self-host.
- **`doCheck = false`** on the Python packages — the upstream test suites are slow and occasionally network/model-dependent (rough on aarch64 / low-memory hosts); `pythonImportsCheck` still runs.
- Added the missing `requests` runtime dep and relaxed the `pygobject<=3.50` pin (nixpkgs ships 3.54+).

Pinned versions: frontend **25.6.0**, API **3.2.0** (the pairing from the PR).

## AI Installation Prompt

> **This repo is the Nix packaging for Gramps Web.** If your host is not running Nix or NixOS, install Gramps Web from its [upstream Docker image](https://www.grampsweb.org/install_setup/setup/) instead; this flake won't help you.
>
> Install Gramps Web via this flake on a Nix-capable host. **Done when** the web UI loads on the configured port and you can create the first (owner) account.
>
> 1. Clone: `git clone https://github.com/nSimonFR/gramps-web-nix && cd gramps-web-nix`
> 2. Read first: `flake.nix`, `module.nix`, `pkgs/python-set.nix`, `README.md`. Everything (Node for the frontend, Python + GTK/GObject-Introspection for the backend) is handled inside the derivations.
> 3. Build the packages (sanity check): `nix build .#gramps-web .#gramps-web-api`. The frontend build (rollup) is memory-hungry (~1 GB) — build it with RAM free.
> 4. Deploy as a NixOS service:
>    - Add this flake to your system flake inputs (`gramps-web-nix.url = "github:nSimonFR/gramps-web-nix";`).
>    - Import `inputs.gramps-web-nix.nixosModules.gramps-web`.
>    - Configure `services.gramps-web = { enable = true; baseUrl = "https://<host>"; redisUrl = "redis://127.0.0.1:6379/<db>"; secretKeyFile = "<path>"; };`
> 5. Provide **Redis** on the same host (Celery broker/result backend). Put the Flask session secret in `secretKeyFile` (kept out of the Nix store).
> 6. `sudo nixos-rebuild switch --flake .#<host>`. Open the configured port; `GET /ready` returns `200` once gunicorn is up.
>
> The service is **always-on**. To make it sleep when idle on a memory-constrained host, wrap `gramps-web.service` with a socket-activation proxy host-side and bind `gramps-web-celery.service` to its lifecycle — the module leaves `host`/`port` configurable for exactly this.

## Usage

### Standalone build

```bash
nix build github:nSimonFR/gramps-web-nix#gramps-web       # frontend
nix build github:nSimonFR/gramps-web-nix#gramps-web-api   # backend
```

### NixOS module

```nix
# flake.nix
inputs.gramps-web-nix.url = "github:nSimonFR/gramps-web-nix";

# configuration.nix
imports = [ inputs.gramps-web-nix.nixosModules.gramps-web ];

services.gramps-web = {
  enable        = true;
  host          = "127.0.0.1";
  port          = 5000;
  baseUrl       = "https://gramps.example.ts.net";
  redisUrl      = "redis://127.0.0.1:6379/6";
  secretKeyFile = "/run/agenix/gramps-web-secret";
};
```

Redis must be reachable at `redisUrl`. The host is responsible for exposing the
port (reverse proxy / Tailscale Serve) and, if desired, socket-activation.

## Options

See `module.nix` for the full set. Key ones: `host`, `port`, `dataDir`,
`baseUrl`, `redisUrl`, `secretKeyFile`, `tree`, `memoryMax`, `celeryMemoryMax`,
`settings` (extra `GRAMPSWEB_*` env).

## Bumping versions

`frontend.nix` (`version`, `src.hash`, `npmDepsHash`) and
`gramps-web-api/default.nix` (`version`, `src.hash`) must be rehashed by hand
after a version bump — set the version, run `nix build`, and copy the
`got:` hashes from the failure. Keep the frontend and API versions a compatible
pair (upstream releases them together).
