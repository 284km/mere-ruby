require "rbconfig"
# Cargo uses the host shared-library suffix, then installs under DLEXT.
p RbConfig::CONFIG.values_at("SOEXT", "DLEXT")
p RbConfig::MAKEFILE_CONFIG.values_at("SOEXT", "DLEXT")
