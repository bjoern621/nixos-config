{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Icons come from the `sddmIcons` flake input (licensed, kept out of repo).
  sddm-beach-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "sddm-beach-theme";
    version = "1.0";
    src = ./sddm-theme/theme;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/beach-clock/icons
      cp -r $src/* $out/share/sddm/themes/beach-clock/
      cp -r ${inputs.sddmIcons}/*.svg $out/share/sddm/themes/beach-clock/icons/
    '';
  };

  # PAM helper: exits 0 if password is empty (face auth), 1 if non-empty (password auth).
  # Used with pam_exec expose_authtok which pipes the password to stdin.
  isPasswordEmpty = pkgs.writeShellScript "sddm-is-password-empty" ''
    read -r password
    [ -z "$password" ]
  '';

  # PAM session helper: decrypts login password from TPM and unlocks GNOME Keyring.
  # This handles keyring unlock after face authentication (where no password is available).
  # For password logins, pam_gnome_keyring in the auth phase already handles this.
  # Runs as the authenticating user via pam_exec seteuid.
  # All status goes to the journal under tag `sddm-keyring-tpm` so failures are diagnosable.
  # See docs/keyring-auto-unlock.md for setup instructions.
  unlockKeyringTpm = pkgs.writeShellScript "sddm-unlock-keyring-tpm" ''
    TAG=sddm-keyring-tpm
    log() { ${pkgs.util-linux}/bin/logger -t "$TAG" -- "$1"; }
    fail() { log "FAIL: $1"; exit 0; }  # exit 0: never block login

    TPM_DIR="$HOME/.tpm"
    if [ ! -d "$TPM_DIR" ]; then
      fail "$TPM_DIR missing. See docs/keyring-auto-unlock.md to seal login password into TPM."
    fi
    for f in password.enc key.pub key.priv; do
      [ -f "$TPM_DIR/$f" ] || fail "$TPM_DIR/$f missing. Re-run setup (docs/keyring-auto-unlock.md)."
    done

    TMP=$(mktemp -d) || fail "mktemp failed"
    trap 'rm -rf "$TMP"' EXIT

    if ! ${pkgs.tpm2-tools}/bin/tpm2_createprimary -Q -c "$TMP/primary.ctx" 2>"$TMP/err"; then
      fail "tpm2_createprimary: $(cat "$TMP/err"). Check tss group membership and /dev/tpmrm0 access."
    fi
    if ! ${pkgs.tpm2-tools}/bin/tpm2_load -Q -C "$TMP/primary.ctx" \
        -u "$TPM_DIR/key.pub" -r "$TPM_DIR/key.priv" -c "$TMP/key.ctx" 2>"$TMP/err"; then
      fail "tpm2_load: $(cat "$TMP/err"). Key files may be from a different TPM/primary; re-seal."
    fi
    if ! ${pkgs.tpm2-tools}/bin/tpm2_encryptdecrypt -Qd -c "$TMP/key.ctx" \
        -o "$TMP/password.txt" "$TPM_DIR/password.enc" 2>"$TMP/err"; then
      fail "tpm2_encryptdecrypt: $(cat "$TMP/err")."
    fi

    if ! ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --unlock < "$TMP/password.txt" >"$TMP/out" 2>&1; then
      fail "gnome-keyring-daemon --unlock: $(cat "$TMP/out"). Stored password may not match current login password; re-seal after password change."
    fi
    log "OK: keyring unlocked via TPM-sealed password"
  '';

  pamUnix = "${pkgs.linux-pam}/lib/security/pam_unix.so";
  pamExec = "${pkgs.linux-pam}/lib/security/pam_exec.so";
  pamHowdy = "${config.services.howdy.package}/lib/security/pam_howdy.so";
  pamGnomeKeyring = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
in
{
  services.displayManager.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "beach-clock";
    extraPackages = with pkgs.kdePackages; [
      qt5compat
      pkgs.bibata-cursors
    ];
    settings.Theme = {
      CursorTheme = "Bibata-Modern-Ice";
      CursorSize = 24;
    };
  };

  # Weston (SDDM's Wayland compositor) needs these exported in its service environment
  # to actually know what cursor to draw, since it doesn't read SDDM's Theme block directly.
  systemd.services.display-manager.environment = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  environment.systemPackages = [
    sddm-beach-theme
    pkgs.tpm2-tools
    pkgs.bibata-cursors
  ];

  # User needs tss group for TPM access (keyring unlock after face login).
  users.users.bjoern.extraGroups = [ "tss" ];

  # Custom SDDM PAM configuration.
  # Replaces the default "auth substack login" which runs howdy before password check.
  # Routes authentication based on whether a password was provided:
  #   - Empty password (face button) → howdy face recognition
  #   - Non-empty password (typed)   → unix password auth only (no howdy)
  security.pam.services.sddm.text = lib.mkForce ''
    # Authentication: branch on empty vs non-empty password.
    #
    # pam_exec checks if the password is empty:
    #   Empty → exit 0 → success=2 skips gnome_keyring + pam_unix verify → lands on howdy.
    #   Non-empty → exit 1 → default=ignore → falls through to password verification.
    #
    # The final `required pam_unix` is never reached during auth (the chain always
    # stops earlier via done/die), but IS called during pam_setcred() for all modules.
    # It reliably provides initgroups() credentials for both auth paths.
    # howdy and pam_exec both return PAM_CRED_INSUFFICIENT from pam_sm_setcred()
    # so they cannot be relied upon to establish credentials.
    auth  optional                    ${pamUnix} likeauth nullok
    auth  [success=2 default=ignore]  ${pamExec} quiet expose_authtok ${isPasswordEmpty}
    auth  optional                    ${pamGnomeKeyring}
    auth  [success=done default=die]  ${pamUnix} nullok try_first_pass
    auth  [success=done default=ignore]  ${pamHowdy}
    auth  required                    ${pamUnix} nullok

    account   include   login
    password  substack  login
    session   include   login
    session   optional  ${pamExec} seteuid quiet ${unlockKeyringTpm}
  '';

  # Clear SDDM's QML cache on every activation so theme changes always apply
  # Also disable KWin's shakecursor effect for the sddm user.
  system.activationScripts.sddm-clear-cache = ''
        rm -rf /var/lib/sddm/.cache/sddm-greeter-qt6/qmlcache

        mkdir -p /var/lib/sddm/.config
        cat <<EOF > /var/lib/sddm/.config/kwinrc
    [Plugins]
    shakecursorEnabled=false
    EOF
        chown -R sddm: /var/lib/sddm/.config
  '';
}
