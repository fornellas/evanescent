# evanescent

[![Build Status](https://travis-ci.org/fornellas/evanescent.svg?branch=master)](https://travis-ci.org/fornellas/evanescent)
[![Gem Version](https://badge.fury.io/rb/evanescent.svg)](http://badge.fury.io/rb/evanescent)
[![GitHub issues](https://img.shields.io/github/issues/fornellas/evanescent.svg)](https://github.com/fornellas/evanescent/issues)
[![GitHub license](https://img.shields.io/badge/license-GPLv3-blue.svg)](https://raw.githubusercontent.com/fornellas/evanescent/master/LICENSE)
[![Downloads](http://ruby-gem-downloads-badge.herokuapp.com/evanescent?type=total)](https://rubygems.org/gems/evanescent)

* Home: https://github.com/fornellas/evanescent/
* Bugs: https://github.com/fornellas/evanescent/issues

## Description

This gem provides an IO like object, that can be used with any logging class (such as Ruby's native Logger). This object will save its input to a file, and allows:
* Hourly or daily rotation.
* Compression of rotated files.
* Removal of old compressed files.
This functionality supplement logging classes, allowing everything related to logging management, to be done within Ruby, without relying on external tools (such as logrotate).

## Install

    gem install evanescent

This gem uses [Semantic Versioning](http://semver.org/), so you should add to your .gemspec something like:
```ruby
  s.add_runtime_dependency 'evanescent', '~> 1.0'
```
Please, always check latest available version!

## Example

### Logger

```ruby
require 'evanescent'
require 'timecop'

logger = Evanescent.logger(
  path: 'test.log',
  rotation: :hourly,
  keep: '2 hours',
)

logger.class # => Logger

# Within first hour, only test.log will exist.
Timecop.freeze(Time.now)
logger.info 'first message'
Dir.entries('.') # => [".", "..", "test.log"]

# One hour later, rotation and compression will happen.
Timecop.freeze(Time.now + 3600)
logger.info 'second message'
Dir.entries('.') # => [".", "..", "test.log", "test.log.2015122315.gz"]

# Another hour later, we'll have 2 compressed files.
Timecop.freeze(Time.now + 3600)
logger.info 'third message'
Dir.entries('.') # => [".", "..", "test.log", "test.log.2015122315.gz", "test.log.2015122316.gz"]

# At last, after keep period, old compressed files are purged.
Timecop.freeze(Time.now + 3600)
logger.info 'fourth message'
Dir.entries('.') # => [".", "..", "test.log", "test.log.2015122316.gz", "test.log.2015122317.gz"]
```

### Generic usage

Evanescent is an IO like object: it responds to <tt>:write</tt> and <tt>:close</tt>:
```ruby
io = Evanescent.new(
  path: 'test.log',
  rotation: :hourly,
  keep: '2 hours',
)
io.write('message') # writes message to test.log
io.close
```

## Limitations

Although Evanescent supports mult-thread operation, inter-process locking is not currently implemented, and behavior is unpredicted in this situation.
