# Security Policy

## Scope

This repository is a private Charmhub-compatible registry service written in Go. Security fixes should favor:

- secure-by-default runtime configuration
- least-privilege deployment settings
- short-lived credentials and token revocation
- dependency and toolchain hygiene

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability.

Report security issues privately to the maintainers with:

- a description of the issue
- affected endpoints or packages
- reproduction steps or proof of concept
- impact assessment
- any suggested mitigation

This service is a mock registry intended for local development and testing. It keeps all state in memory, enables insecure dev bearer tokens by default, and is not intended for production use. Still, treat any registry credentials you configure as confidential and rotate them after any suspected exposure.

## Supported posture

The repository currently includes:

- `golangci-lint` with a curated rule set inspired by Juju's Go linting configuration
- `govulncheck` for dependency and standard-library vulnerability scanning
- `gosec` for Go-focused static security analysis
- explicit HTTP server timeouts and header/body limits
- non-root container execution for the application image

## Hardening expectations

Production deployments should additionally provide:

- TLS termination
- network-level access control for private registry traffic
- secret management outside the repository
- regular Go patch upgrades
- routine vulnerability scanning of container images and dependencies
