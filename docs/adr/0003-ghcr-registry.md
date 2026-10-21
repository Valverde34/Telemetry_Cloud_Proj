# ADR 0003: GitHub Container Registry for images

Status: accepted

## Context

CI needs somewhere to publish images that Azure can pull from.

## Decision

Use GitHub Container Registry (ghcr.io), pushed from the pipeline with the built-in `GITHUB_TOKEN`. Images are tagged with the commit SHA (immutable, used for deploys) and `latest`.

## Consequences

- No extra cloud resource or credential to manage; packages are public, like the repository.
- Azure Container Registry would be preferable for private images (pull with managed identity, private endpoint, vulnerability scanning in Defender).
