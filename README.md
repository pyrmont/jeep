# Jeep

[![Test Status](https://github.com/pyrmont/jeep/workflows/test/badge.svg)](https://github.com/pyrmont/jeep/actions?query=workflow%3Atest)

Jeep is a bundle management utility for Janet bundles.

> [!WARNING]
> Jeep is in a beta stage of development. There are likely to be bugs and gaps
> in its implementation.

Jeep only supports modern bundles. That is bundles that use the `info.jdn`
format for describing metadata. It does not work with legacy bundles, bundles
that use `project.janet`.

## Installation

Clone the repository and run `janet lib/cli.janet install`. If Jeep is already
installed, you can reinstall with `janet lib/cli.janet install -r`.

## Usage

Jeep offers the following commands for use at both the global and bundle level:

- `jeep install`
- `jeep list`
- `jeep new`
- `jeep quickbin`
- `jeep uninstall`

The following commands work at the bundle level only:

- `jeep api`
- `jeep build`
- `jeep clean`
- `jeep dep`
- `jeep meta`
- `jeep prep`
- `jeep test`

More information about each subcommand is available by running `jeep help
<subcommand>`.

## Versioning

Jeep uses the label `DEVEL` during development. When a new version is released,
a tag is created for that version in the repository.

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/jeep/issues

## Licence

Jeep is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/jeep/blob/master/LICENSE
