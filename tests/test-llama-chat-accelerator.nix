# Pin for the llama-chat accelerator switch (pure eval, no VM; 2026-11-28
# iGPU flip).
#
# services.llama-chat.accelerator decides where the 23.4 GB chat model runs.
# "cpu" is the page-cache posture this host ran 2026-10-05..2026-11-27;
# "igpu" moves every layer into GTT through the HIP build. The iGPU unit's
# shape is what keeps it working and keeps it bounded — the render group +
# strict device cgroup are what let a non-root unit reach /dev/kfd without
# touching the NPU node (the 2026-09-04 D-state corpse class), and
# `--load-mode none` keeps the load off the mmap upload that carries the
# llama.cpp #19482 ROCr spin. This check makes each half a tested invariant,
# and pins that "cpu" stays byte-for-byte the old unit.
#
# Same rationale as test-inboxclean-paperless.nix: a MINIMAL nixosSystem,
# not evo-x2.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  llamaChatModule =
    (import ../modules/nixos/services/llama-chat.nix { }).flake.nixosModules.llama-chat;

  primaryUserStub = {
    options.users.primaryUser = lib.mkOption { type = lib.types.str; };
    users.primaryUser = "lars";
  };

  eval =
    extra:
    (lib.nixosSystem {
      inherit system;
      modules = [
        llamaChatModule
        primaryUserStub
        { system.stateVersion = "26.11"; }
        extra
      ];
    }).config;

  igpu = eval { services.llama-chat.accelerator = "igpu"; };
  cpu = eval { };

  igpuUnit = igpu.systemd.services.llama-chat;
  cpuUnit = cpu.systemd.services.llama-chat;

  igpuExec = igpuUnit.serviceConfig.ExecStart;
  cpuExec = cpuUnit.serviceConfig.ExecStart;

  hasAllow =
    sc: needle:
    builtins.any (entry: lib.hasPrefix needle (builtins.toJSON entry)) (sc.DeviceAllow or [ ]);

  cases = [
    {
      name = "igpu: ExecStart lost --gpu-layers";
      pass = lib.hasInfix " --gpu-layers all " igpuExec;
    }
    {
      name = "igpu: ExecStart lost --load-mode none (the #19482 mmap escape)";
      pass = lib.hasInfix " --load-mode none " igpuExec;
    }
    {
      name = "igpu: no render group — /dev/kfd is unreachable for a non-root unit";
      pass = igpuUnit.serviceConfig.SupplementaryGroups or [ ] == [ "render" ];
    }
    {
      name = "igpu: device policy is not strict";
      pass = igpuUnit.serviceConfig.DevicePolicy or "" == "strict";
    }
    {
      name = "igpu: /dev/kfd missing from DeviceAllow";
      pass = hasAllow igpuUnit.serviceConfig "/dev/kfd";
    }
    {
      name = "igpu: char-drm missing from DeviceAllow";
      pass = hasAllow igpuUnit.serviceConfig "char-drm";
    }
    {
      name = "igpu: HSA_OVERRIDE_GFX_VERSION missing from the unit environment";
      pass = igpuUnit.environment.HSA_OVERRIDE_GFX_VERSION or "" == "11.5.1";
    }
    {
      name = "igpu: HSA_ENABLE_SDMA missing from the unit environment";
      pass = igpuUnit.environment.HSA_ENABLE_SDMA or "" == "0";
    }
    {
      name = "igpu: LD_LIBRARY_PATH no longer names the ROCm runtime";
      pass = lib.hasInfix "rocm-runtime" (igpuUnit.environment.LD_LIBRARY_PATH or "");
    }
    {
      name = "igpu: package is not the HIP build ai-stack ships (two surfaces forked)";
      pass =
        igpu.services.llama-chat.package.outPath == (pkgs.llama-cpp.override { rocmSupport = true; })
        .outPath;
    }
    {
      name = "igpu: unit description no longer names the iGPU posture";
      pass = lib.hasInfix "iGPU" igpuUnit.description;
    }
    {
      name = "cpu: ExecStart grew GPU flags";
      pass = !(lib.hasInfix "--gpu-layers" cpuExec || lib.hasInfix "--load-mode" cpuExec);
    }
    {
      name = "cpu: unit gained a render group";
      pass = cpuUnit.serviceConfig.SupplementaryGroups or [ ] == [ ];
    }
    {
      name = "cpu: unit gained a device policy";
      pass = !(cpuUnit.serviceConfig ? DevicePolicy);
    }
    {
      name = "cpu: unit gained ROCm environment";
      pass = cpuUnit.environment == { };
    }
    {
      name = "cpu: package is no longer the plain llama.cpp build";
      pass = cpu.services.llama-chat.package == pkgs.llama-cpp;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "llama-chat-accelerator-render-test" { } "touch $out"
else
  pkgs.runCommand "llama-chat-accelerator-render-test" { } ''
    echo "llama-chat accelerator render test FAILED for: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
