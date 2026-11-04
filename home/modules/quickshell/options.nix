{ lib, ... }:

{
  options.quickshell = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Quickshell with its private runtime deps.";
    };

    powerActions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Actions the power menu offers. Modules add their own.";
    };
  };
}
