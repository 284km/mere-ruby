# Loaded by the test launcher for every interpreter, including -I/-C/- children.
# Only build configuration is supplied; upstream assertions are unchanged.
require 'rbconfig'
require_relative 'build_config' if ENV.fetch('NATIVE_MKMF_SIDE') == 'mere'
build = ENV.fetch('NATIVE_MKMF_BUILD')
$top_srcdir = ENV.fetch('NATIVE_MKMF_SOURCE')
$topdir = build
RbConfig.fire_update!('topdir', build)
RbConfig.fire_update!('EXTOUT', '.ext')
