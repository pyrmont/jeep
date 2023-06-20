# Jeep

Jeep is a project management utility for Janet.

It has the following features:

- development dependencies

## Installation

Clone the repository and run `jpm install`.

## Usage

Jeep is invoked using the `jeep` command-line utility. `jeep` supports
the following subcommands:

- **`dev-deps`**: Install dependencies and development dependencies
- **`doc`**: Generate an API document
- **`netrepl`**: Start a netrepl server

Additional subcommands are passed through to `jpm`. For example, running `jeep
build` will invoke `jpm build`.

More information about each subcommand is available by running `jeep help
<subcommand>`.

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/jeep/issues

## Licence

Jeep is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/jeep/blob/master/LICENSE
