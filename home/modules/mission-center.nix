{ ... }:

{
  dconf.settings = {
    "io/missioncenter/MissionCenter" = {
      performance-smooth-graphs = true;
      performance-sliding-graphs = true;
      # 300 data points = 5 minutes (default 60 = 1 minute)
      performance-page-data-points = 300;
      apps-page-merged-process-stats = true;
    };
  };
}
