# Shell Tools Monorepo

A collection of MIT-licensed shell scripts and utilities organized in a monorepo structure.

## Structure

- `tools/`: Individual CLI tools and scripts.
- `lib/`: Shared shell libraries and functions used across multiple tools.

## Getting Started

This repository uses [pnpm](https://pnpm.io/) to manage the monorepo structure and dependencies.

### Prerequisites

- [pnpm](https://pnpm.io/installation)
- [ShellCheck](https://www.shellcheck.net/) (recommended for development)

### Development

To install dependencies (if any tools use node-based helpers):
```bash
pnpm install
```

## Contributing

Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for details on how to add new tools or libraries.

## License

MIT © 2026
