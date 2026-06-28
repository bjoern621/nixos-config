{
  config,
  lib,
  pkgs,
  ...
}:

let
  # PAM helper: exits 0 if the piped password is empty (face auth), 1 if
  # non-empty (password auth). Used with pam_exec expose_authtok, which pipes
  # the entered authtok to stdin. Same mechanism as the SDDM login stack in
  # modules/display-manager.nix.
  isPasswordEmpty = pkgs.writeShellScript "qs-lock-is-password-empty" ''
    read -r password
    [ -z "$password" ]
  '';

  # PAM helper: exits 0 when the piped authtok is the passkey sentinel the lock
  # sends for a passkey attempt (LockContext.qml passkeySentinel), routing it to
  # pam_u2f. Matches the SDDM login token in modules/display-manager.nix.
  isPasskeyToken = pkgs.writeShellScript "qs-lock-is-passkey-token" ''
    read -r token
    [ "$token" = "__fido2_passkey__" ]
  '';

  pamUnix = "${pkgs.linux-pam}/lib/security/pam_unix.so";
  pamExec = "${pkgs.linux-pam}/lib/security/pam_exec.so";
  pamPermit = "${pkgs.linux-pam}/lib/security/pam_permit.so";
  pamHowdy = "${config.services.howdy.package}/lib/security/pam_howdy.so";
  pamU2f = "${pkgs.pam_u2f}/lib/security/pam_u2f.so";
  u2fAuthfile = config.security.pam.u2f.settings.authfile;
in
{
  # PAM stack consumed by the Quickshell session lock (PamContext config
  # "quickshell-lock"). The lock runs in the user's Quickshell process, so this
  # stack authenticates as that user.
  #
  # Three separate paths chosen by what the lock sends as the response, mirroring
  # the SDDM login in modules/display-manager.nix. No method is a second factor:
  #   passkey button (sentinel)  -> pam_u2f only.
  #   face button (empty)        -> Howdy only.
  #   typed password             -> pam_unix only.
  #
  # PamContext only drives the auth phase, so only auth rules matter here; the
  # account rule keeps the file well-formed.
  #
  # Rule walk (auth):
  #   1 pam_unix optional        - prompts once, captures the authtok (nullok so
  #                                an empty entry from the face button is allowed).
  #   2 pam_exec isPasskeyToken  - sentinel: success -> skip rules 3,4, land on
  #                                pam_u2f. Otherwise ignored, fall through to 3.
  #   3 pam_exec isPasswordEmpty - empty: success -> skip rules 4,5, land on
  #                                Howdy. Otherwise ignored, fall through to 4.
  #   4 pam_unix try_first_pass  - password path: reuses the captured authtok.
  #                                Correct -> done; wrong -> die.
  #   5 pam_u2f                  - passkey path: touched -> done; any failure dies
  #                                without falling through to face.
  #   6 pam_howdy                - face path: success -> done; failure -> ignore.
  #   7 pam_unix required        - face/password backstop. try_first_pass reuses
  #                                the empty authtok (no second prompt); it cannot
  #                                satisfy pam_unix against a real password, so the
  #                                attempt is rejected here.
  security.pam.services.quickshell-lock.text = lib.mkForce ''
    auth  optional                    ${pamUnix} likeauth nullok
    auth  [success=2 default=ignore]  ${pamExec} quiet expose_authtok ${isPasskeyToken}
    auth  [success=2 default=ignore]  ${pamExec} quiet expose_authtok ${isPasswordEmpty}
    auth  [success=done default=die]  ${pamUnix} nullok try_first_pass
    auth  [success=done default=die]  ${pamU2f} authfile=${u2fAuthfile} cue
    auth  [success=done default=ignore]  ${pamHowdy}
    auth  required                    ${pamUnix} nullok try_first_pass

    account  required  ${pamPermit}
  '';
}
