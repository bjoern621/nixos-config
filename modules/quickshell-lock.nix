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

  pamUnix = "${pkgs.linux-pam}/lib/security/pam_unix.so";
  pamExec = "${pkgs.linux-pam}/lib/security/pam_exec.so";
  pamPermit = "${pkgs.linux-pam}/lib/security/pam_permit.so";
  pamHowdy = "${config.services.howdy.package}/lib/security/pam_howdy.so";
in
{
  # PAM stack consumed by the Quickshell session lock (PamContext config
  # "quickshell-lock"). The lock runs in the user's Quickshell process, so this
  # stack authenticates as that user.
  #
  # Routing mirrors the SDDM login in modules/display-manager.nix:
  #   empty password (face button) -> howdy face recognition
  #   typed password               -> pam_unix
  #
  # PamContext only drives the auth phase, so only auth rules matter here; the
  # account rule keeps the file well-formed.
  #
  # Rule walk (auth):
  #   1 pam_unix optional        - prompts once, captures the authtok (nullok so
  #                                an empty entry from the face button is allowed).
  #   2 pam_exec isPasswordEmpty - empty authtok: success -> skip rule 3, land on
  #                                howdy. Non-empty: ignored, fall through to 3.
  #   3 pam_unix try_first_pass  - password path: reuses the captured authtok.
  #                                Correct -> done; wrong -> die.
  #   4 pam_howdy                - face path: success -> done; failure -> ignore.
  #   5 pam_unix required        - backstop, only reached when a face attempt
  #                                fails. try_first_pass reuses the empty authtok
  #                                (no second prompt); it cannot satisfy pam_unix
  #                                against a real password, so the attempt is
  #                                rejected here.
  security.pam.services.quickshell-lock.text = lib.mkForce ''
    auth  optional                    ${pamUnix} likeauth nullok
    auth  [success=1 default=ignore]  ${pamExec} quiet expose_authtok ${isPasswordEmpty}
    auth  [success=done default=die]  ${pamUnix} nullok try_first_pass
    auth  [success=done default=ignore]  ${pamHowdy}
    auth  required                    ${pamUnix} nullok try_first_pass

    account  required  ${pamPermit}
  '';
}
