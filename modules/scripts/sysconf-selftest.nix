{ pkgs, ... }:

# Live health checks for the running system. Runner + per-test files are
# bundled into the store; the wrapper only sets PATH and points the runner at
# them. Add a test by dropping a file in selftest/tests/ (see selftest/lib.sh
# for the contract).
let
  sysconf-selftest = pkgs.writeShellApplication {
    name = "sysconf-selftest";
    runtimeInputs = with pkgs; [
      hyprland # hyprctl
      jq
      gnugrep
      gnused
      ncurses # tput
      coreutils # sleep, printf, basename
      bash
    ];
    text = ''
      export SELFTEST_LIB=${./selftest/lib.sh}
      export SELFTEST_TESTS=${./selftest/tests}
      exec bash ${./selftest/runner.sh} "$@"
    '';
  };
in
{
  environment.systemPackages = [ sysconf-selftest ];
}
