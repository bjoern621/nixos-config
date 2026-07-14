{ ... }:

{
  # WORKAROUND (nixpkgs-unstable, Python 3.14 default): face-recognition-models
  # imports pkg_resources at runtime (face_recognition_models/__init__.py) but
  # only declares setuptools as a build-system input, so pkg_resources is not in
  # its runtime closure. On Python <= 3.13 pkg_resources happened to be present
  # in the interpreter env, masking the gap; on 3.14 it is absent. The failing
  # `import face_recognition_models` then makes face_recognition/api.py call
  # quit(), which aborts face-recognition's pytest check phase and fails the
  # howdy build.
  #
  # The default `setuptools` (82.x) no longer ships pkg_resources, so it cannot
  # satisfy this. setuptools_80 (which the package already pins as its
  # build-system) still ships pkg_resources; declaring it as a runtime
  # dependency restores the module at import time.
  # Remove once nixpkgs fixes face-recognition-models upstream.
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          face-recognition-models = pyprev.face-recognition-models.overridePythonAttrs (old: {
            dependencies = (old.dependencies or [ ]) ++ [ pyfinal.setuptools_80 ];
          });

          # WORKAROUND (nixpkgs-unstable): howdy pulls opencv4Full, whose VTK
          # feature drags in vtk -> gdal-minimal/pdal, which fail to build from
          # source in this nixpkgs snapshot and are not cached. Howdy only uses
          # opencv for camera capture and never touches VTK, so disabling it
          # drops the broken subtree without affecting howdy.
          # Remove once vtk builds again upstream.
          opencv4Full = pyprev.opencv4Full.override { enableVtk = false; };
        })
      ];
    })
  ];

  # Howdy is a face recognition authentication system for Linux. It can be used as a PAM (Pluggable Authentication Modules) module to allow users to log in using their face.
  services.howdy = {
    enable = true;
    control = "sufficient"; # Face recognition is enough to authenticate (password as fallback)
    settings = {
      video = {
        device_path = "/dev/video2"; # Integrated IR camera
        dark_threshold = 85;
        timeout = 3; # Seconds to wait for a face to be recognized
      };
      core = {
        abort_if_lid_closed = true;
        abort_if_ssh = true;
      };
    };
  };

  # IR emitter must be enabled for the IR camera to work in the dark.
  # Run `sudo -E linux-enable-ir-emitter configure -m` after first rebuild to calibrate.
  services.linux-enable-ir-emitter.enable = true;
}
