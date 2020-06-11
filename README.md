# gdtags

Generate tags for Godot Engine's GDScript in ctags or json format.

## Install

- Check the latest release for any prebuilt binaries for your platform.
- Build Nim Source
  - Git clone or download this repository. `cd` to it, then run `nimble install`.

## Usage

For full usage help run `gdtags -h`.

Recursively generate tags for a directory:

    gdtags -R # current directory
    gdtags -R /path/to/directory
    gdtags --emacs -R # current directory
    gdtags --emacs -R /path/to/directory

Recursively generate tags for a directory but skip addons:

    gdtags -R --exclude='^\./addons'
    gdtags --emacs -R --exclude='^\./addons'

Recursively generate tags for a directory and skip addons except your addon:

    gdtags -R --exclude='^\./addons' --exclude-exception='^\./addons/okay'
    gdtags --emacs -R --exclude='^\./addons' --exclude-exception='^\./addons/okay'

Generate tags for a file:

    gdtags file
    gdtags --emacs file

Generate tags for [vista.vim](https://github.com/liuchengxu/vista.vim):

    # omit class name tags for better looking presentation
    gdtags --sort=no --omit-class-name --output-format=json
