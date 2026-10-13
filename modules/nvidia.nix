{ config, pkgs, ... }:

# Blackwell runs on the open kernel module alone,
# and the NixOS module refuses to choose a flavour on its own.
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.nvidia-vaapi-driver ];
  };

  hardware.nvidia = {
    open = true;
    # 595.x breaks EGL for Minecraft 26.3 (eglChooseConfig EGL_BAD_DISPLAY); fixed in 615+.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    nvidiaSettings = true;
  };

  # The CPU's iGPU stays on in firmware and enumerates as a second card.
  # Aquamarine renders on the first card it finds unless told which one,
  # and the PCI address differs per board, so udev names the card by vendor.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", ATTRS{vendor}=="0x10de", SYMLINK+="dri/nvidia-card"
  '';

  environment.sessionVariables = {
    AQ_DRM_DEVICES = "/dev/dri/nvidia-card";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
}
