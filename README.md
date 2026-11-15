# opencode-batteries-included

The official [OpenCode](https://opencode.ai) image with git, Python, Node and a build toolchain added.

Upstream is Alpine with the `opencode` binary, ripgrep and BusyBox. That covers the web UI, but an agent that wants to clone a repo, run tests or build a native addon gets nowhere.

| Added | Why |
| --- | --- |
| `git`, `openssh-client` | clones, commits, worktrees, `git@` remotes |
| `git-lfs` | repositories that track large files |
| `github-cli` | issues, pull requests, auth |
| `bash`, `coreutils`, GNU `grep`/`sed`/`awk`/`findutils`/`tar`/`gzip`/`xz`/`zip` | a shell and GNU tools that scripts expect |
| `python3`, `pip`, `python3-dev`, `uv` | Python work; `uvx` runs tools without installing them |
| `nodejs`, `npm` | JavaScript and TypeScript; `npx` does the same |
| `nodejs-dev` | headers for node-gyp, so native addons build offline |
| `build-base`, `cmake`, `pkgconf` | native addons and source packages |
| `autoconf`, `automake`, `libtool`, `linux-headers` | source builds (native crypto packages, C libraries) |
| `libffi-dev`, `openssl-dev`, `zlib-dev` | C-extension builds against system crypto |
| `sqlite`, `tzdata`, `file` | SQL shell, timezone data, mimetype detection |
| `curl`, `jq`, `ca-certificates`, `openssl` | everyday plumbing |

`nodejs-dev` is Alpine's header package for the Node that is already installed, not a second runtime. It adds `/usr/include/node` and about 1.4 MB. Alpine builds Node with `use_prefix_to_find_headers`, so node-gyp finds those headers on its own and compiles native addons without downloading anything; that works with a read-only root and every capability dropped.

Everything upstream stays as-is: I kept the same base image, the same `ENTRYPOINT ["opencode"]`, the same root user and the same paths under `/root`. The added `CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]` just starts the server with sane flags, and `WORKDIR /workspace` gives you a directory for clones. The image also bakes environment defaults that keep it self-sufficient with no compose assistance: `SHELL`, `HISTFILE`, `PATH`, `XDG_CACHE_HOME=/tmp/cache`, `NPM_CONFIG_PREFIX`/`NPM_CONFIG_USERCONFIG`/`NPM_CONFIG_CACHE`, `UV_LINK_MODE=copy`, `PIP_BREAK_SYSTEM_PACKAGES`, `GIT_CONFIG_GLOBAL` (with an empty `gitconfig` to keep `git config` happy), `GIT_SSH_COMMAND` and `OPENCODE_DISABLE_AUTOUPDATE=1`. Override any of them with `docker run -e`.

## Authentication

The web UI asks for a password on its connect screen. The username is always `opencode` and the password is whatever you pass as `OPENCODE_PASSWORD`. Sessions last 30 days; pairing links from `opencode pair` also work. Without a password set, nothing checks credentials against anyone - set one.

`/global/health` is intentionally unauthenticated and returns `200` - useful for health checks. Everything else requires credentials; without one, pages render but every API call returns `401`.

## Tags

Each OpenCode release gets a rebuild, so `2.3.0` means OpenCode 2.3.0 with the image's current tooling. `2.2` and `2` track the newest build of their line, and `latest` follows everything. Deploy a full version; the aliases move.

## Run

```yaml
services:
  opencode:
    image: ghcr.io/greythx/opencode-batteries-included:2.3.0
    init: true
    restart: unless-stopped
    command: ["serve", "--hostname", "0.0.0.0", "--port", "4096"]
    working_dir: /workspace
    ports:
      - "127.0.0.1:4096:4096"
    environment:
      OPENCODE_PASSWORD: "${OPENCODE_PASSWORD:?set a password}"
    volumes:
      - data:/root/.local
      - config:/root/.config
      - projects:/workspace
      - ssh:/root/.ssh
    read_only: true
    tmpfs:
      - /tmp:size=1g,mode=1777,exec
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    pids_limit: 4096
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://127.0.0.1:4096/global/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

volumes:
  data:
  config:
  projects:
  ssh:
```

Four volumes hold everything worth keeping: sessions, auth and the packages installed with `npm -g` or `pip install` under `/root/.local`; OpenCode config, the `gh` login, git config and npmrc under `/root/.config`; clones under `/workspace`; keys and `known_hosts` under `/root/.ssh`. Delete a volume and that part starts over.

The image needs no support beyond itself, the password and the port binding. A plain `docker run -d -p 127.0.0.1:4096:4096 -e OPENCODE_PASSWORD=secret ghcr.io/greythx/opencode-batteries-included:2.3.0` works without any of the compose above.

The published port binds `127.0.0.1`. Plain `0.0.0.0` would hand the web UI to anyone on the network with the password in clear on the wire, so don't do it. For remote access use a private tunnel such as Tailscale, or a reverse proxy with its own TLS or auth.

For a plain start without any deployment shape, `docker run -d -p 127.0.0.1:4096:4096 -e OPENCODE_PASSWORD=secret ghcr.io/greythx/opencode-batteries-included:2.3.0` works as is.

## Platforms

`linux/amd64` and `linux/arm64`: x86-64 servers, Intel Macs, Apple Silicon, ARM servers. Upstream publishes nothing else, so neither does this.

## Build it yourself

```bash
docker build --build-arg OPENCODE_VERSION=2.3.0 -t opencode-batteries-included .
docker run --rm --entrypoint sh opencode-batteries-included -c 'git --version && uvx --version && npx --version'
```

The `2.3.0` in those commands is an example; check the newest release at https://github.com/anomalyco/opencode/releases before you build.

The `OPENCODE_VERSION` default in the Dockerfile tracks the current stable version. CI passes the real version on every build; the default only keeps a plain `docker build .` working.

## Updates

The workflow polls every six hours. It reads the newest stable release from `anomalyco/opencode`, waits for a later run if upstream hasn't published the matching image yet, and skips versions already built here. Otherwise it builds amd64 and arm64 (arm64 compiles under QEMU), runs a smoke test inside the image, including HTTP-level checks on the running server, and pushes only if the test passes.

A new major version needs no extra wiring; the next poll picks it up. Polling is the only option, because GitHub can't notify this repository when another one cuts a release. Publishing is automatic; restarting your container is not.

A manual run takes a version such as `2.3.0` or `v2.3.0` and rejects anything that isn't `X.Y.Z`. If upstream has no image for that version, the run fails instead of sitting green with nothing published. A pull request that touches the build files gets a build-only check before merging.

There are no lockfiles, dependency PRs or bot commits per release. OpenCode versions come from the release feed; tool versions come from Alpine's index.

## Notes

- Runs as root, because upstream does. I'd rather match the official image than win a security argument.
- Every capability is dropped above. Nothing in the image needs one; add them back only if a tool you install asks for it.
- Version tags are mutable: a Dockerfile change rebuilds the current OpenCode version under the same tag.
- About 1.5 GB uncompressed. The compiler, two runtimes and the GNU userland are most of it.
- `apk` is there for a plain `docker run`. With a read-only root an agent cannot add packages, so put them in the Dockerfile, or reach for `uvx` and `npx`.
- The image carries `/root/.config/gitconfig` and `/root/.config/npmrc` as empty files: `git config --global` dies with a fatal error on a missing file, not with a warning.
- `gh auth login` and `git config` are not preconfigured; the agent has to do those itself. `gh auth setup-git` is also not done for you.
- `opencode --server` is for the CLI client; the web UI pairs with the server itself, via `opencode pair` or password. Fronting that URL with another origin without its own auth is not supported.
- The image and the example deployment both keep their data under the four volumes. `docker compose down -v` destroys all local state.

## License

MIT.
