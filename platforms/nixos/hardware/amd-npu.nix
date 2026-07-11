{
  pkgs,
  nix-amd-npu,
  ...
}:
let
  # Fix XRT build with Boost 1.89.0 - boost_system was removed in 1.87+
  # Use callPackage to override the boost input to the XRT package
  xrt-fixed = pkgs.callPackage (nix-amd-npu + "/pkgs/xrt") {
    boost = pkgs.boost187;
  };
in
{
  # AMD NPU (XDNA) Support for Ryzen AI Max+ 395 (Strix Halo)
  # Requires kernel 6.14+ (6.19.8 current) with built-in amdxdna driver
  # Provides: XRT runtime, XDNA shim plugin, udev rules, memlock limits

  hardware.amd-npu = {
    enable = true;
    enableDevTools = true;
    memlockLimit = "unlimited";
    package = xrt-fixed;
  };
}
