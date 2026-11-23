{ ... }:

{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";

    plugins.smart-enter = ./smart-enter.yazi;
    initLua = ./init.lua;

    keymap.mgr.prepend_keymap = [
      {
        on = "<Enter>";
        run = "plugin smart-enter";
        desc = "Enter the child directory, or open the file";
      }
      {
        on = "<Backspace>";
        run = "leave";
        desc = "Back to the parent directory";
      }
      {
        on = "<Delete>";
        run = "remove";
        desc = "Trash selected files";
      }
      {
        on = "<C-c>";
        run = "yank";
        desc = "Yank selected files (copy)";
      }
      {
        on = "<C-x>";
        run = "yank --cut";
        desc = "Yank selected files (cut)";
      }
      {
        on = "<C-v>";
        run = "paste";
        desc = "Paste yanked files";
      }
    ];
  };
}
