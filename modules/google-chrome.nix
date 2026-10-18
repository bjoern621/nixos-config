{ pkgs, ... }:

{
  environment.etc."opt/chrome/policies/managed/nixos.json".text = builtins.toJSON {
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Google";
    DefaultSearchProviderKeyword = "google.com";
    DefaultSearchProviderSearchURL = "https://www.google.com/search?q={searchTerms}";

    # DefaultSearchProviderName = "Startpage";
    # DefaultSearchProviderKeyword = "startpage.com";
    # DefaultSearchProviderSearchURL = "https://www.startpage.com/sp/search?query={searchTerms}";

    ExtensionSettings = {
      "*" = {
        installation_mode = "allowed";
      };

      # Bitwarden
      "nngceckbapebfimnlniiiahkandclblb" = {
        installation_mode = "force_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
        # default_pinned applies only on first install; extension already installed.
        toolbar_pin = "force_pinned";
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

      # Tabliss - A Beautiful New Tab
      "hipekcciheckooncpjeljhnekcoolahp" = {
        installation_mode = "force_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };
    };

    # 1 = restore the last session ("Continue where you left off")
    RestoreOnStartup = 1;

    BookmarkBarEnabled = true;

    PromotionalTabsEnabled = false;
    PromotionsEnabled = false;
    WelcomePageOnOSUpgradeEnabled = false;
    DefaultBrowserSettingEnabled = false;

    NTPFooterManagementNoticeEnabled = false;
    NTPFooterExtensionAttributionEnabled = false;

    # Bitwarden counts as default only with Chrome passwords, addresses and cards autofill off.
    PasswordManagerEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;

    TranslateEnabled = false;
    LiveTranslateEnabled = false;

    # Extension managed storage; Bitwarden schema exposes only `environment`.
    # Other extension settings (e.g. quick copy) live in local storage, not policy.
    "3rdparty".extensions."nngceckbapebfimnlniiiahkandclblb".environment.base =
      "https://bitwarden.bjoernblessin.de";
  };
}
