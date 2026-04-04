# Contributing to SpinningDonut

Thanks for contributing! This project is intentionally low-level and performance-sensitive, so please follow these guidelines.

## Development workflow

1. Fork and create a feature branch.
2. Make focused changes.
3. Run full verification locally:
   - `make verify`
4. Open a pull request with clear rationale.

## Coding standards

- Keep assembly comments concise and meaningful.
- Prefer explicit error paths over implicit assumptions.
- Keep syscall behavior and register usage documented around non-trivial code.
- Avoid unnecessary style churn.

## Commit message style

Use imperative style and scope where practical, for example:

- `runtime: harden ioctl failure cleanup`
- `ci: add artifact checksum verification`

## Pull request checklist

- [ ] Builds cleanly (`make build`)
- [ ] Validation passes (`make verify`)
- [ ] Documentation updated when behavior changes
- [ ] No unrelated refactors
