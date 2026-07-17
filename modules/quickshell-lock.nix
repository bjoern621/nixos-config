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
  # IFS= stops read trimming leading/trailing whitespace.
  # All-blank password is a password, not a face attempt.
  isPasswordEmpty = pkgs.writeShellScript "qs-lock-is-password-empty" ''
    IFS= read -r password
    [ -z "$password" ]
  '';

  # PAM helper: exits 0 when the piped authtok is the passkey sentinel the lock
  # sends for a passkey attempt (LockContext.qml passkeySentinel), routing it to
  # pam_u2f. Matches the SDDM login token in modules/display-manager.nix.
  # IFS= stops read trimming, so only the exact sentinel routes to pam_u2f.
  isPasskeyToken = pkgs.writeShellScript "qs-lock-is-passkey-token" ''
    IFS= read -r token
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
  # nullok appears only on rule 1, whose result is discarded. The enforcing
  # pam_unix rules (4, 7) omit it: pam_unix consults nullok solely when the
  # stored hash is empty, so on an enforcing rule it converts "deny" into
  # "unlock with no authentication". Rule 7 needs no nullok to accept the face
  # path's empty authtok, because it never accepts it: try_first_pass consumes
  # the non-NULL empty string from rule 1 without re-prompting, then fails
  # against a real hash. That rejection is the point of rule 7.
  #
  # Rule walk (auth):
  #   1 pam_unix optional        - prompts once, captures the authtok for rules
  #                                2, 3, 4 and 7. optional: result discarded, only
  #                                the capture matters.
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
    auth  [success=done default=die]  ${pamUnix} try_first_pass
    auth  [success=done default=die]  ${pamU2f} authfile=${u2fAuthfile} cue
    auth  [success=done default=ignore]  ${pamHowdy}
    auth  required                    ${pamUnix} try_first_pass

    account  required  ${pamPermit}
  '';
}
