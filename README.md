# opencode-batteries-included

The official [OpenCode](https://opencode.ai) image with git, Python, Node and a build toolchain added.

Upstream is Alpine with the `opencode` binary, ripgrep and BusyBox. That covers the web UI, but an agent that wants to clone a repo, run tests or build a native addon gets nowhere.

| Added | Why |
| --- | --- |
| `git`, `openssh-client` | clones, commits, worktrees, `git@` remotes |
| `github-cli` | issues, pull requests, auth |
| `bash`, `coreutils` | a shell and GNU tools that scripts expect |
| `python3`, `pip`, `python3-dev`, `uv` | Python work; `uvx` runs tools without installing them |
| `nodejs`, `npm` | JavaScript and TypeScript; `npx` does the same |
| `nodejs-dev` | headers for node-gyp, so native addons build offline |
| `build-base`, `cmake`, `pkgconf` | native addons and source packages |
| `curl`, `jq`, `unzip`, `ca-certificates`, `openssl` | everyday plumbing |

`nodejs-dev` is Alpine's header package for the Node that is already installed, not a second runtime. It adds `/usr/include/node` and about 1.4 MB. The image sets `npm_config_nodedir=/usr`, so node-gyp compiles against those headers instead of downloading a matching tarball and unpacking it. The download fails on a read-only root with every capability dropped; the system headers do not.

Everything upstream stays as-is: I kept the same base, the same `ENTRYPOINT ["opencode"]`, the same root user and `/root`, and no `CMD`, `WORKDIR` or `HEALTHCHECK`. `npm_config_nodedir` is the only added setting, and it only matters when a package compiles.

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
      - "4096:4096"
    environment:
      OPENCODE_PASSWORD: "${OPENCODE_PASSWORD:?set a password}"
      PATH: "/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      PIP_BREAK_SYSTEM_PACKAGES: "1"
      PIP_USER: "1"
      NPM_CONFIG_PREFIX: /root/.local
      NPM_CONFIG_USERCONFIG: /root/.config/npmrc
      NPM_CONFIG_CACHE: /tmp/npm
      UV_LINK_MODE: copy
      GIT_CONFIG_GLOBAL: /root/.config/gitconfig
      XDG_CACHE_HOME: /tmp/cache
      HISTFILE: /root/.local/state/bash_history
      SHELL: /bin/bash
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

volumes:
  data:
  config:
  projects:
  ssh:
```

Four volumes hold everything worth keeping: sessions, auth and the packages installed with `npm -g` or `pip install --user` under `/root/.local`; OpenCode config, the `gh` login, git config and npmrc under `/root/.config`; clones under `/workspace`; keys and `known_hosts` under `/root/.ssh`. Delete a volume and that part starts over.

Most of the environment exists because the root filesystem is read-only. Caches move to the tmpfs, `NPM_CONFIG_USERCONFIG` and `GIT_CONFIG_GLOBAL` point at the config volume, `UV_LINK_MODE=copy` stops uv from hardlinking out of its cache, and `HISTFILE` keeps shell history. `SHELL` gives terminal sessions bash rather than BusyBox `sh`. `PIP_BREAK_SYSTEM_PACKAGES` is needed on Alpine's externally managed Python, and `PIP_USER` plus `NPM_CONFIG_PREFIX` send installs to the data volume so they survive a restart.

`/tmp` is the only writable path outside the volumes, and its tmpfs needs `exec`: native builds and `uv` write binaries there and run them.

For a plain start, remove `read_only`, the tmpfs and the two cache variables.

## Platforms

`linux/amd64` and `linux/arm64`: x86-64 servers, Intel Macs, Apple Silicon, ARM servers. Upstream publishes nothing else, so neither does this.

## Build it yourself

```bash
docker build --build-arg OPENCODE_VERSION=2.3.0 -t opencode-batteries-included .
docker run --rm --entrypoint sh opencode-batteries-included -c 'git --version && uvx --version && npx --version'
```

The `2.3.0` in those commands is an example; check the newest release at https://github.com/anomalyco/opencode/releases before you build.

The `OPENCODE_VERSION` default in the Dockerfile is stale on purpose. CI passes the real version on every build; the default only keeps a plain `docker build .` working.

## Updates

The workflow polls every six hours. It reads the newest stable release from `anomalyco/opencode`, waits for a later run if upstream hasn't published the matching image yet, and skips versions already built here. Otherwise it builds amd64 and arm64 (arm64 compiles under QEMU), runs a smoke test inside the image, and pushes only if the test passes.

A new major version needs no extra wiring; the next poll picks it up. Polling is the only option, because GitHub can't notify this repository when another one cuts a release. Publishing is automatic; restarting your container is not.

A manual run takes a version such as `2.3.0` or `v2.3.0` and rejects anything that isn't `X.Y.Z`. If upstream has no image for that version, the run fails instead of sitting green with nothing published.

GitHub disables scheduled workflows in public repositories after 60 days without activity. To keep that from silently stopping future builds, the workflow makes an empty commit after 45 quiet days.

There are no lockfiles, dependency PRs or bot commits per release. OpenCode versions come from the release feed; tool versions come from Alpine's index.

After the first push, set the package to public: Packages → the package → Package settings → Change visibility.

## Notes

- Runs as root, because upstream does. I'd rather match the official image than win a security argument.
- Every capability is dropped above. Nothing in the image needs one; add them back only if a tool you install asks for it.
- Version tags are mutable: a Dockerfile change rebuilds the current OpenCode version under the same tag.
- About 900 MB uncompressed, 350 MB to pull. The compiler and two runtimes are most of it.
- `apk` is there for a plain `docker run`. With a read-only root an agent cannot add packages, so put them in the Dockerfile, or reach for `uvx` and `npx`.

## License

MIT.
