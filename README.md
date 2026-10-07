# Mock Charm Registry

A single Go binary that speaks the Charmhub API subset needed by stock `charmcraft` and stock `juju`. All state is in memory and discarded when the process exits.

## Run it

```bash
make build
./.bin/charm-registry &
```

Or without building:

```bash
make run
```

The API listens on [http://localhost:18080](http://localhost:18080).

## Point the clients at it

```bash
export CHARMCRAFT_STORE_API_URL=http://localhost:18080
export CHARMCRAFT_UPLOAD_URL=http://localhost:18080
export CHARMCRAFT_REGISTRY_URL=http://localhost:18080

juju bootstrap localhost dev --config charmhub-url=http://localhost:18080
```

For local-only auth, use an insecure development bearer token:

```text
Authorization: Bearer dev:alice:alice
```

## End-to-end demo

[demo.sh](demo.sh) starts the registry, builds a bogus charm, pushes it with `charmcraft`, and deploys it with `juju`:

```bash
./demo.sh
```

## Configuration

See [.env.example](.env.example). Every variable has a default, so the binary runs with no configuration at all.
