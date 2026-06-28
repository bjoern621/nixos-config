{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Shared visual face (LoginPanel.qml) and design tokens live in the Quickshell
  # lock config and are the single source of truth. They are copied into the SDDM
  # theme at build time so the login screen and the session lock stay identical.
  # See home/modules/quickshell/config/lock/LoginPanel.qml.
  lockShared = ../home/modules/quickshell/config/lock;

  sddm-beach-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "sddm-beach-theme";
    version = "1.0";
    src = ./sddm-theme/theme;
    dontBuild = true;
    installPhase = ''
      themeDir="$out/share/sddm/themes/beach-clock"
      mkdir -p "$themeDir"

      # Theme-specific files: Main.qml, Globals.qml, qmldir, metadata.desktop, theme.conf.
      cp -r $src/* "$themeDir/"

      # Shared face and design tokens from the lock config.
      install -m644 \
        ${lockShared}/LoginPanel.qml \
        ${lockShared}/Colors.qml \
        ${lockShared}/Typography.qml \
        ${lockShared}/Spacing.qml \
        ${lockShared}/Label.qml \
        ${lockShared}/TintedIcon.qml \
        ${lockShared}/Spinner.qml \
        ${lockShared}/FadeBehavior.qml \
        ${lockShared}/SquishBehavior.qml \
        "$themeDir/"
      cp -r ${lockShared}/icons "$themeDir/"
    '';
  };

  # PAM helper: exits 0 if password is empty (face auth), 1 if non-empty (password auth).
  # Used with pam_exec expose_authtok which pipes the password to stdin.
  isPasswordEmpty = pkgs.writeShellScript "sddm-is-password-empty" ''
    read -r password
    [ -z "$password" ]
  '';

  # PAM helper: exits 0 when the piped authtok is the passkey sentinel that the
  # passkey button sends (modules/sddm-theme/theme/Main.qml passkeySentinel), 1
  # otherwise. Routes a passkey attempt to pam_u2f. The token is not a secret and
  # authenticates nothing on its own; the key still gates.
  isPasskeyToken = pkgs.writeShellScript "sddm-is-passkey-token" ''
    read -r token
    [ "$token" = "__fido2_passkey__" ]
  '';

  # PAM session helper: unlocks the GNOME Keyring after face login by decrypting
  # the login password from TPM. Status logged under journal tag `sddm-keyring-tpm`.
  # Setup: docs/keyring-auto-unlock.md.
  unlockKeyringTpm = pkgs.writeShellScript "sddm-unlock-keyring-tpm" ''
    TAG=sddm-keyring-tpm
    log() { ${pkgs.util-linux}/bin/logger -t "$TAG" -- "$1"; }
    fail() { log "FAIL: $1"; exit 0; }  # exit 0: never block login

    TPM_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/sddm/keyring-tpm"
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

    # pam_exec runs us as root; gnome-keyring would abort with
    # "failed dropping capabilities -9". runuser drops to PAM_USER and zeroes caps.
    [ -n "$PAM_USER" ] || fail "PAM_USER not set."
    if ! ${pkgs.util-linux}/bin/runuser -u "$PAM_USER" -- \
        ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --unlock < "$TMP/password.txt" >"$TMP/out" 2>&1; then
      fail "gnome-keyring-daemon --unlock: $(cat "$TMP/out"). Stored password may not match current login password; re-seal after password change."
    fi
    log "OK: keyring unlocked via TPM-sealed password"
  '';

  pamUnix = "${pkgs.linux-pam}/lib/security/pam_unix.so";
  pamExec = "${pkgs.linux-pam}/lib/security/pam_exec.so";
  pamHowdy = "${config.services.howdy.package}/lib/security/pam_howdy.so";
  pamGnomeKeyring = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
  pamU2f = "${pkgs.pam_u2f}/lib/security/pam_u2f.so";
  u2fAuthfile = config.security.pam.u2f.settings.authfile;
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

  # Weston (SDDM's Wayland compositor) doesn't read SDDM's Theme block, so
  # export the cursor here too.
  systemd.services.display-manager.environment = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  environment.systemPackages = [
    sddm-beach-theme
    pkgs.tpm2-tools
    pkgs.bibata-cursors
  ];

  # `tss` group + udev rules for /dev/tpmrm0 access (TPM keyring unlock).
  security.tpm2.enable = true;
  users.users.bjoern.extraGroups = [ "tss" ];

  # SDDM PAM: three separate paths chosen by what the greeter sends as the
  # password, so each method stands alone (no method is a second factor on top
  # of another):
  #   Passkey button (sentinel token) → pam_u2f only. Touch -> done; any failure
  #                                     dies without falling through to face.
  #   Face button / empty submit ("") → Howdy face only (pam_u2f is skipped).
  #   Typed password                  → pam_unix only (key and face skipped).
  # The two pam_exec classifiers jump to the matching method:
  #   isPasskeyToken success (3) skips isPasswordEmpty, gnome_keyring and the
  #     typed-password pam_unix, landing on pam_u2f.
  #   isPasswordEmpty success (3) skips gnome_keyring, pam_unix and pam_u2f,
  #     landing on Howdy.
  # The final `required pam_unix` is the face/password backstop; it is also
  # called by pam_setcred() to establish initgroups credentials (howdy and
  # pam_exec both return PAM_CRED_INSUFFICIENT from setcred).
  security.pam.services.sddm.text = lib.mkForce ''
    auth  optional                    ${pamUnix} likeauth nullok
    auth  [success=3 default=ignore]  ${pamExec} quiet expose_authtok ${isPasskeyToken}
    auth  [success=3 default=ignore]  ${pamExec} quiet expose_authtok ${isPasswordEmpty}
    auth  optional                    ${pamGnomeKeyring}
    auth  [success=done default=die]  ${pamUnix} nullok try_first_pass
    auth  [success=done default=die]  ${pamU2f} authfile=${u2fAuthfile} cue
    auth  [success=done default=ignore]  ${pamHowdy}
    auth  required                    ${pamUnix} nullok

    account   include   login
    password  substack  login
    session   include   login
    session   optional  ${pamExec} seteuid quiet ${unlockKeyringTpm}
  '';

  # Clear SDDM's QML cache so theme changes apply, and disable KWin's
  # shakecursor effect for the sddm user.
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
