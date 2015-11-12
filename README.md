# evanescent

[![GitHub issues](https://img.shields.io/github/issues/fornellas/evanescent.svg)](https://github.com/fornellas/evanescent/issues)
[![GitHub license](https://img.shields.io/badge/license-GPLv3-blue.svg)](https://raw.githubusercontent.com/fornellas/evanescent/master/LICENSE)

* Home: https://github.com/fornellas/evanescent/
* Bugs: https://github.com/fornellas/evanescent/issues

## Description

This gem provides an IO object, that can be used with any logging class (such as Ruby's native Logger). This object will save its input to a file, and allows:
* Rotation by time / date.
* Compression of old files.
* Removal of old compressed files.
Its purpuse is to supplement logging classes, allowing everything related to logging management, to be done within Ruby, without relying on external tools (such as logrotate).

## Install

    gem install evanescent

This gem uses [Semantic Versioning](http://semver.org/), so you should add to your .gemspec something like:
```ruby
  s.add_runtime_dependency 'evanescent', '~> 0.0'
```
Please, always check latest available version!

## Examples

TODO
