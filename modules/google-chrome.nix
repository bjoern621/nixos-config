{ pkgs, ... }:

{
  environment.etc."opt/chrome/policies/managed/nixos.json".text = builtins.toJSON {
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Google";
    DefaultSearchProviderKeyword = "google.com";
    DefaultSearchProviderSearchURL = "https://www.google.com/search?q={searchTerms}";

    ExtensionSettings = {
      "*" = {
        installation_mode = "allowed";
      };

      # Bitwarden
      "nngceckbapebfimnlniiiahkandclblb" = {
        installation_mode = "force_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };

      # uBlock Origin Lite
      "ddkjiahejlhfcafbddmgiahcphecmpfh" = {
        installation_mode = "force_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };

      # Refined GitHub
      "hlepfoohegkhhmjieoechaddaejaokhf" = {
        installation_mode = "force_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };
    };

    # 1 = restore the last session ("Continue where you left off")
    RestoreOnStartup = 1;

    PromotionalTabsEnabled = false;
    PromotionsEnabled = false;
    WelcomePageOnOSUpgradeEnabled = false;
    DefaultBrowserSettingEnabled = false;

    PasswordManagerEnabled = false;

    TranslateEnabled = false;
    LiveTranslateEnabled = false;
  };
}
