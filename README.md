# Jeep

Jeep is a project management utility for Janet bundles.

> [!WARNING]
> Jeep is in a beta stage of development. There are likely to be bugs and gaps
> in its implementation.

Jeep only supports projects that use the `info.jdn` format for describing
metadata. It does not work with bundles that use `project.janet`.

## Installation

Clone the repository and run `janet lib/cli.janet install`.

## Usage

Jeep offers the following commands for use at both the global and project level:

- `jeep install`
- `jeep quickbin`
- `jeep uninstall`

The following commands work at the project level only:

- `jeep build`
- `jeep clean`
- `jeep dep`
- `jeep prep`
- `jeep test`

More information about each subcommand is available by running `jeep help
<subcommand>`.

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/jeep/issues

## Licence

Jeep is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/jeep/blob/master/LICENSE
