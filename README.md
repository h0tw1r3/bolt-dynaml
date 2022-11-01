## Bolt Dynaml plugin

This module provides a Bolt inventory plugin for resolving values with ERB
and optionally merging external data.

#### Table of Contents

1. [Usage](#usage)
2. [Examples](#examples)

## Usage

The plugin supports two parameters. Choose either or both.
If both are provided, the plugin will merge or replace `value` with the value
of `merge.key` in `merge.file`.

- `value`: A string or structure of values to parse with erb
- `merge`: (optional)
  - `file`: yaml file to load, defaults to _override.yaml_
  - `key`: key in the file to merge with the optional value parameter

`merge.file` variables can be referenced by inline erb using the builtin
variable `@dynaml`. Key names are symbols.

## Examples

```
version: 2
targets:
  - _plugin: puppetdb
    query:
      _plugin: dynaml
      value: "nodes[certname] { report_timestamp<'<%= (Time.now.utc - 1*60).strftime('%FT%T.%LZ') %>' }"
  - _plugin: dynaml
    value:
      pm_api_url: "https://<%= @dynaml[:proxmox][:host] %>/api2/json"
config:
  _plugin: dynaml
  merge:
    file: custom.yaml
    key: config
  value:
    ssh:
      user: root
      host-key-check: false
      private-key: "<%= opts[:_boltdir] %>/private_key.pem"
```
