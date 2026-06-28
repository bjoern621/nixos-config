{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Exit 0 if a FIDO authenticator is currently connected, 1 otherwise.
  # pam_u2f returns PAM_AUTH_ERR both when no key is inserted and when a present
  # key misses its touch, so the return code alone cannot tell the two apart.
  # Device presence is the discriminator used to decide whether a failed key
  # attempt deserves a visible message. fido2-token -L prints one line per
  # connected authenticator.
  fidoPresent = pkgs.writeShellScript "fido-device-present" ''
    out="$(${pkgs.libfido2}/bin/fido2-token -L 2>/dev/null)"
    [ -n "$out" ]
  '';

  pamExec = "${pkgs.linux-pam}/lib/security/pam_exec.so";
  pamEcho = "${pkgs.linux-pam}/lib/security/pam_echo.so";
in
{
  # FIDO2 passkey authentication via pam_u2f, using the two YubiKeys as a third
  # login method alongside the password and Howdy face recognition.
  #
  # control = "sufficient": a registered key that is present and touched is
  # enough to authenticate on its own (password OR face OR key). When no key is
  # inserted, pam_u2f's detection fails immediately (no cue, no delay) and PAM
  # falls through to the next method ("insert on demand").
  #
  # Enabling this globally adds the rule to the generated stacks for sudo, login,
  # su, polkit and similar services. The SDDM login (modules/display-manager.nix)
  # and the Quickshell session lock (modules/quickshell-lock.nix) override their
  # PAM text with lib.mkForce, so the rule is spliced into those stacks by hand;
  # both read the same package path and authfile from this option.
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      # Central authfile readable by root-run services (sudo, the SDDM greeter)
      # and by the user-run lock. It holds only public credentials, so it is not
      # secret. Touch-only: no pinverification, so a tap is enough.
      authfile = "/etc/u2f-mappings";
      cue = true;
    };
  };

  # Prompt order on the auto-generated stacks: face first, key second, password
  # last. Howdy and pam_u2f both run automatically and in sequence on a terminal
  # sudo and on graphical polkit prompts, so Howdy (order 11500) should fire the
  # camera before pam_u2f. By default u2f sorts ahead at 10900; push it past
  # Howdy but before pam_unix (11700) so the key is the fallback when face fails.
  security.pam.services.sudo.rules.auth.u2f.order = lib.mkForce 11600;
  security.pam.services."polkit-1".rules.auth.u2f.order = lib.mkForce 11600;

  # Failure feedback on terminal sudo. When the key step fails (face already
  # failed, then the key missed its touch) and a FIDO device is actually
  # connected, print a message before the password prompt. With no device
  # connected (the plain password/face path) pam_u2f also returns PAM_AUTH_ERR,
  # but the presence check fails and the message is skipped, so password logins
  # stay quiet. Placed between u2f (11600) and pam_unix (11700):
  #   11630 pam_exec - device present -> continue to the message; otherwise skip
  #                    the next rule (the message).
  #   11660 pam_echo - the message; optional, so it prints and PAM then proceeds
  #                    to the password prompt.
  security.pam.services.sudo.rules.auth.fidoFailCheck = {
    control = "[success=ignore default=1]";
    modulePath = pamExec;
    args = [ "quiet" "${fidoPresent}" ];
    order = 11630;
  };
  security.pam.services.sudo.rules.auth.fidoFailMsg = {
    control = "optional";
    modulePath = pamEcho;
    args = [ "FIDO" "authentication" "failed." ];
    order = 11660;
  };

  # pamu2fcfg lives here for the one-time key registration.
  environment.systemPackages = [ pkgs.pam_u2f ];

  # Register keys with pamu2fcfg (from pkgs.pam_u2f, above). Insert key 1 and
  # touch it for the first command, then key 2 for the second; paste joins both
  # credentials onto the single line pam_u2f expects:
  #
  #   ( pamu2fcfg -u bjoern; pamu2fcfg -u bjoern -n ) \
  #       | paste -sd '' - | sudo tee /etc/u2f-mappings
  #
  # The line reads:  bjoern:<cred-key1>:<cred-key2>
  # pamu2fcfg defaults to origin/appid pam://<hostname>, matching pam_u2f, so no
  # extra origin flags are needed. Any registered key then works.
}
