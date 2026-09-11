{ inputs, ... }:

{
  imports = [ inputs.ttydnd.homeModules.default ];

  programs.ttydnd.enable = true;

  # Replaces the system alias whole, so --color=tty has to come along.
  # ll and l are spelled in terms of ls, so they pick the hyperlinks up too.
  home.shellAliases.ls = "ls --color=tty --hyperlink=auto";
}
