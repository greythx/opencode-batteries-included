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
| `build-base`, `cmake`, `pkgconf` | native addons and source packages |
| `curl`, `jq`, `unzip`, `ca-certificates`, `openssl` | everyday plumbing |

Everything upstream stays as-is: I kept the same base, the same `ENTRYPOINT ["opencode"]`, the same root user and `/root`, and no `CMD`, `WORKDIR` or `HEALTHCHECK`. The entrypoint matters most. Anything that swaps this image in for the official one should behave the same.

## Tags

Each OpenCode release gets a rebuild, so `2.2.7` means OpenCode 2.2.7 with the image's current tooling. `2.2` and `2` track the newest build of their line, and `latest` follows everything. Deploy a full version; the aliases move.

## Run

```bash
docker run -d --name opencode \
  -p 4096:4096 \
  -v opencode-home:/root \
  ghcr.io/greythx/opencode-batteries-included:2.2.7 \
  serve --hostname 0.0.0.0 --port 4096
```

The volume is what keeps sessions and auth between restarts. Delete it and you start from scratch.

## Platforms

`linux/amd64` and `linux/arm64`: x86-64 servers, Intel Macs, Apple Silicon, ARM servers. Upstream publishes nothing else, so neither does this.

## Build it yourself

```bash
docker build --build-arg OPENCODE_VERSION=2.2.7 -t opencode-batteries-included .
docker run --rm --entrypoint sh opencode-batteries-included -c 'git --version && uvx --version && npx --version'
```

The `2.2.7` in those commands is an example; check the newest release at https://github.com/anomalyco/opencode/releases before you build.

The `OPENCODE_VERSION` default in the Dockerfile is stale on purpose. CI passes the real version on every build; the default only keeps a plain `docker build .` working.

## Updates

The workflow polls every six hours. It reads the newest stable release from `anomalyco/opencode`, waits for a later run if upstream hasn't published the matching image yet, and skips versions already built here. Otherwise it builds amd64 and arm64 (arm64 compiles under QEMU), runs a smoke test inside the image, and pushes only if the test passes.

A new major version needs no extra wiring; the next poll picks it up. Polling is the only option, because GitHub can't notify this repository when another one cuts a release. Publishing is automatic; restarting your container is not.

A manual run takes a version such as `2.2.7` or `v2.2.7` and rejects anything that isn't `X.Y.Z`. If upstream has no image for that version, the run fails instead of sitting green with nothing published.

GitHub disables scheduled workflows in public repositories after 60 days without activity. To keep that from silently stopping future builds, the workflow makes an empty commit after 45 quiet days.

There are no lockfiles, dependency PRs or bot commits per release. OpenCode versions come from the release feed; tool versions come from Alpine's index.

After the first push, set the package to public: Packages → the package → Package settings → Change visibility.

## Notes

- Runs as root, because upstream does. I'd rather match the official image than win a security argument.
- Version tags are mutable: a Dockerfile change rebuilds the current OpenCode version under the same tag.
- About 900 MB uncompressed, 350 MB to pull. The compiler and two runtimes are most of it.
- `apk` stays, so an agent can install a one-off tool at runtime.

## License

MIT.
