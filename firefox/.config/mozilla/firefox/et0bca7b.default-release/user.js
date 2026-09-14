// Enable userChrome.css / userContent.css customizations
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Keep the downloads button in the toolbar always visible, not just during/after a download
user_pref("browser.download.autohideButton", false);
// Always resume the previous session on launch instead of Fedora's default start page
user_pref("browser.startup.page", 3);
// Fedora's Firefox build (firefox-redhat-default-prefs.js) hardcodes
// browser.startup.homepage to https://start.fedoraproject.org/ - override
// it directly so nothing (extra recovery tab, homepage button, etc.) can
// land there
user_pref("browser.startup.homepage", "about:blank");
