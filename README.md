# Dockerized Diagnostic CLI

A single Bash command-line tool, packaged as a Docker image, that reports Linux
system information, checks a host over the network, and shows disk usage. One
entrypoint (`app/diagnostic.sh`) dispatches subcommands, and a standalone health
probe (`app/health-check.sh`) backs the container healthcheck.

## Requirements

- Docker (with Compose v2, i.e. the `docker compose` subcommand).

## Build

From the project root:

```bash
docker build -t diagnostic-cli .
```

## Usage

The image takes a subcommand as its argument. With no argument it shows help.

```bash
docker run --rm diagnostic-cli system
docker run --rm diagnostic-cli network example.com
docker run --rm diagnostic-cli disk
docker run --rm diagnostic-cli help
```

### Commands

| Command            | Description                                   | Exit codes |
|--------------------|-----------------------------------------------|------------|
| `system`           | Show hostname, user, OS, kernel, uptime, CPU, memory, working directory | `0` |
| `network <host>`   | Resolve the host and check connectivity       | `0` reachable, `1` unreachable, `2` missing host |
| `disk`             | Show filesystem disk usage (`df`)             | `0` |
| `help`             | Show usage                                    | `0` |

Exit-code contract across the tool: `0` success, `1` operational/runtime
failure, `2` invalid command or missing required argument.

## Running with Docker Compose

A `diagnostic` service is defined in `compose.yaml`:

```bash
docker compose run --rm diagnostic system
docker compose run --rm diagnostic disk
```

The service also declares a healthcheck that runs `app/health-check.sh`, which
verifies the required tools are present and that the core subcommands run.

## Testing

`test.sh` builds the image and asserts the core behaviors (help, system, disk,
and invalid-command handling):

```bash
./test.sh
```

The instructor grader builds the image, runs the container commands, validates
the Compose configuration, and runs `test.sh`. Because it drives Docker itself,
run it on a host with Docker available:

```bash
chmod +x grade.sh app/*.sh test.sh
./grade.sh
```

## Logs

Subcommands append timestamped entries (`TIMESTAMP [script] message`) to
`logs/diagnostic.log` inside the container. Under `docker run --rm` without a
mounted volume these logs are ephemeral and removed with the container. The
`logs/` directory is excluded from the Docker build context via `.dockerignore`.

## Assumptions

- The image is based on `ubuntu:22.04` and installs only the packages the
  subcommands need (`iproute2`, `iputils-ping`, `dnsutils`, `procps`,
  `netcat-openbsd`).
- `ENTRYPOINT` is the diagnostic script and `CMD` defaults to `help`, so a
  subcommand passed to `docker run` replaces the default.
- The network check prefers `ping`, falling back to a Bash `/dev/tcp` probe when
  `ping` is unavailable, so it still works on restricted networks.
- No secrets or machine-specific values are stored in the repository.
