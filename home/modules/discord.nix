{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.discord.commandLineArgs = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Flags passed to Discord at launch.";
  };

  config.home.packages = [
    (pkgs.discord.override { inherit (config.discord) commandLineArgs; })
  ];
}
