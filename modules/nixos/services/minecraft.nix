# Minecraft server/client with Prism Launcher and modpack management
_: {
  flake.nixosModules.minecraft = {
    config,
    pkgs,
    lib,
    ...
  }: let
    mcVersion = "26.1.2";
    inherit (config.users) primaryUser;
    mcJarSha1 = "97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51";
    mcJarUrl = "https://piston-data.mojang.com/v1/objects/${mcJarSha1}/server.jar";
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;

    minecraft-server-26 = pkgs.stdenv.mkDerivation {
      pname = "minecraft-server";
      version = mcVersion;

      src = pkgs.fetchurl {
        url = mcJarUrl;
        sha1 = mcJarSha1;
      };

      nativeBuildInputs = [pkgs.makeWrapper];

      installPhase = ''
        runHook preInstall

        install -Dm644 $src $out/lib/minecraft/server.jar

        makeWrapper ${lib.getExe pkgs.jdk25.headless} $out/bin/minecraft-server \
          --append-flags "-jar $out/lib/minecraft/server.jar nogui" \
          ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [pkgs.udev]}"}

        runHook postInstall
      '';

      dontUnpack = true;

      passthru.updateScript = [];

      meta = {
        description = "Minecraft Server";
        homepage = "https://minecraft.net";
        sourceProvenance = with lib.sourceTypes; [binaryBytecode];
        license = lib.licenses.unfreeRedistributable;
        platforms = lib.platforms.unix;
        mainProgram = "minecraft-server";
      };
    };
    cfg = config.services.minecraft;
    ccfg = cfg.client;

    # FOV conversion: Minecraft stores FOV as a normalized value where
    # 0.0 = 70° (normal), 1.0 = 110° (wide). Formula: (degrees - 70) / 40
    fovToNormalized = degrees: (degrees - 70) / 40.0;

    # Sound volume conversion: percentage (0-100) to Minecraft's 0.0-1.0 float
    pctToVolume = pct: pct / 100.0;

    # Generate the full options.txt for Prism Launcher client instances
    clientOptionsFile = pkgs.writeText "options.txt" ''
      version:4790
      ao:true
      biomeBlendRadius:2
      chunkSectionFadeInTime:0.75
      cutoutLeaves:true
      enableVsync:true
      entityDistanceScaling:1.0
      entityShadows:true
      forceUnicodeFont:false
      japaneseGlyphVariants:false
      fov:${toString (fovToNormalized ccfg.fov)}
      fovEffectScale:${toString ccfg.fovEffectScale}
      darknessEffectScale:1.0
      glintSpeed:0.5
      glintStrength:0.75
      graphicsPreset:"fancy"
      prioritizeChunkUpdates:1
      fullscreen:false
      exclusiveFullscreen:false
      gamma:${toString ccfg.gamma}
      guiScale:${toString ccfg.guiScale}
      maxAnisotropyBit:1
      textureFiltering:1
      maxFps:120
      improvedTransparency:false
      inactivityFpsLimit:"afk"
      mipmapLevels:4
      narrator:0
      particles:0
      reducedDebugInfo:false
      renderClouds:"true"
      cloudRange:64
      renderDistance:${toString ccfg.renderDistance}
      simulationDistance:${toString ccfg.simulationDistance}
      screenEffectScale:1.0
      soundDevice:""
      vignette:true
      weatherRadius:10
      autoJump:false
      rotateWithMinecart:false
      operatorItemsTab:false
      autoSuggestions:true
      chatColors:true
      chatLinks:true
      chatLinksPrompt:true
      discrete_mouse_scroll:false
      invertXMouse:false
      invertYMouse:false
      realmsNotifications:true
      showSubtitles:false
      directionalAudio:true
      touchscreen:false
      bobView:true
      toggleCrouch:false
      toggleSprint:false
      toggleAttack:false
      toggleUse:false
      sprintWindow:7
      darkMojangStudiosBackground:false
      hideLightningFlashes:false
      hideSplashTexts:false
      mouseSensitivity:0.5
      damageTiltStrength:1.0
      highContrast:false
      highContrastBlockOutline:false
      narratorHotkey:true
      resourcePacks:[]
      incompatibleResourcePacks:[]
      lastServer:
      lang:en_us
      chatVisibility:0
      chatOpacity:1.0
      chatLineSpacing:0.0
      textBackgroundOpacity:0.5
      backgroundForChatOnly:true
      hideServerAddress:false
      advancedItemTooltips:false
      pauseOnLostFocus:true
      overrideWidth:0
      overrideHeight:0
      chatHeightFocused:1.0
      chatDelay:0.0
      chatHeightUnfocused:0.4375
      chatScale:1.0
      chatWidth:1.0
      notificationDisplayTime:1.0
      useNativeTransport:true
      mainHand:"right"
      attackIndicator:1
      tutorialStep:none
      mouseWheelSensitivity:1.0
      rawMouseInput:true
      allowCursorChanges:true
      glDebugVerbosity:1
      skipMultiplayerWarning:true
      hideMatchedNames:true
      joinedFirstServer:true
      syncChunkWrites:false
      showAutosaveIndicator:true
      allowServerListing:true
      onlyShowSecureChat:false
      saveChatDrafts:false
      panoramaScrollSpeed:1.0
      telemetryOptInExtra:false
      onboardAccessibility:false
      menuBackgroundBlurriness:5
      startedCleanly:true
      musicToast:"never"
      musicFrequency:"DEFAULT"
      key_key.attack:key.mouse.left
      key_key.use:key.mouse.right
      key_key.forward:key.keyboard.w
      key_key.left:key.keyboard.a
      key_key.back:key.keyboard.s
      key_key.right:key.keyboard.d
      key_key.jump:key.keyboard.space
      key_key.sneak:key.keyboard.left.shift
      key_key.sprint:key.keyboard.left.control
      key_key.drop:key.keyboard.q
      key_key.inventory:key.keyboard.e
      key_key.chat:key.keyboard.t
      key_key.playerlist:key.keyboard.tab
      key_key.pickItem:key.mouse.middle
      key_key.command:key.keyboard.slash
      key_key.socialInteractions:key.keyboard.p
      key_key.toggleGui:key.keyboard.f1
      key_key.toggleSpectatorShaderEffects:key.keyboard.f4
      key_key.screenshot:key.keyboard.f2
      key_key.togglePerspective:key.keyboard.f5
      key_key.smoothCamera:key.keyboard.unknown
      key_key.fullscreen:key.keyboard.f11
      key_key.spectatorOutlines:key.keyboard.unknown
      key_key.spectatorHotbar:key.mouse.middle
      key_key.swapOffhand:key.keyboard.f
      key_key.saveToolbarActivator:key.keyboard.c
      key_key.loadToolbarActivator:key.keyboard.x
      key_key.advancements:key.keyboard.l
      key_key.quickActions:key.keyboard.g
      key_key.debug.overlay:key.keyboard.f3
      key_key.debug.modifier:key.keyboard.f3
      key_key.hotbar.1:key.keyboard.1
      key_key.hotbar.2:key.keyboard.2
      key_key.hotbar.3:key.keyboard.3
      key_key.hotbar.4:key.keyboard.4
      key_key.hotbar.5:key.keyboard.5
      key_key.hotbar.6:key.keyboard.6
      key_key.hotbar.7:key.keyboard.7
      key_key.hotbar.8:key.keyboard.8
      key_key.hotbar.9:key.keyboard.9
      key_key.debug.reloadChunk:key.keyboard.a
      key_key.debug.showHitboxes:key.keyboard.b
      key_key.debug.clearChat:key.keyboard.d
      key_key.debug.crash:key.keyboard.c
      key_key.debug.showChunkBorders:key.keyboard.g
      key_key.debug.showAdvancedTooltips:key.keyboard.h
      key_key.debug.copyRecreateCommand:key.keyboard.i
      key_key.debug.spectate:key.keyboard.n
      key_key.debug.switchGameMode:key.keyboard.f4
      key_key.debug.debugOptions:key.keyboard.f6
      key_key.debug.focusPause:key.keyboard.p
      key_key.debug.dumpDynamicTextures:key.keyboard.s
      key_key.debug.reloadResourcePacks:key.keyboard.t
      key_key.debug.profiling:key.keyboard.l
      key_key.debug.copyLocation:key.keyboard.c
      key_key.debug.dumpVersion:key.keyboard.v
      key_key.debug.profilingChart:key.keyboard.1
      key_key.debug.fpsCharts:key.keyboard.2
      key_key.debug.networkCharts:key.keyboard.3
      key_key.debug.lightmapTexture:key.keyboard.4
      soundCategory_master:${toString (pctToVolume ccfg.sound.master)}
      soundCategory_music:${toString (pctToVolume ccfg.sound.music)}
      soundCategory_record:${toString (pctToVolume ccfg.sound.noteBlocks)}
      soundCategory_weather:${toString (pctToVolume ccfg.sound.weather)}
      soundCategory_block:1.0
      soundCategory_hostile:${toString (pctToVolume ccfg.sound.hostile)}
      soundCategory_neutral:1.0
      soundCategory_player:1.0
      soundCategory_ambient:${toString (pctToVolume ccfg.sound.ambient)}
      soundCategory_voice:${toString (pctToVolume ccfg.sound.voice)}
      soundCategory_ui:1.0
      modelPart_cape:true
      modelPart_jacket:true
      modelPart_left_sleeve:true
      modelPart_right_sleeve:true
      modelPart_left_pants_leg:true
      modelPart_right_pants_leg:true
      modelPart_hat:true
    '';
  in {
    options.services.minecraft = {
      enable = lib.mkEnableOption "Minecraft server";

      port = serviceTypes.servicePort 25565 "Server port";

      jvmOpts = lib.mkOption {
        type = lib.types.str;
        default = "-Xms2G -Xmx4G -XX:+UseCompactObjectHeaders -XX:+AlwaysPreTouch -XX:+UseStringDeduplication -XX:+UseZGC";
        description = "JVM arguments for the server";
      };

      difficulty = lib.mkOption {
        type = lib.types.enum ["peaceful" "easy" "normal" "hard"];
        default = "normal";
        description = "Game difficulty";
      };

      maxPlayers = lib.mkOption {
        type = lib.types.ints.positive;
        default = 20;
        description = "Maximum number of players";
      };

      motd = lib.mkOption {
        type = lib.types.str;
        default = "§bHome §rMinecraft";
        description = "Message of the day shown in the server list";
      };

      viewDistance = lib.mkOption {
        type = lib.types.ints.positive;
        default = 16;
        description = "View distance in chunks";
      };

      simulationDistance = lib.mkOption {
        type = lib.types.ints.positive;
        default = 12;
        description = "Simulation distance in chunks";
      };

      whitelist = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Whitelist entries (username → UUID)";
        example = {"Player" = "uuid-here";};
      };

      client = {
        enable = lib.mkEnableOption "Minecraft client settings management via Prism Launcher";

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "Home Manager user for client settings";
        };

        instanceName = lib.mkOption {
          type = lib.types.str;
          default = mcVersion;
          description = "Prism Launcher instance name (directory name under instances/)";
        };

        fov = lib.mkOption {
          type = lib.types.ints.between 30 110;
          default = 70;
          description = "Field of view in degrees (30=minimum, 70=normal, 110=maximum)";
        };

        fovEffectScale = lib.mkOption {
          type = lib.types.float;
          default = 1.0;
          description = "FOV effect scaling (0.0=off, 1.0=full)";
        };

        guiScale = lib.mkOption {
          type = lib.types.ints.between 0 10;
          default = 0;
          description = "GUI scale (0=auto, 1-10=specific scale)";
        };

        gamma = lib.mkOption {
          type = lib.types.float;
          default = 0.5;
          description = "Brightness (0.0=moody, 0.5=default, 1.0=bright)";
        };

        renderDistance = lib.mkOption {
          type = lib.types.ints.between 2 32;
          default = 16;
          description = "Render distance in chunks (client-side)";
        };

        simulationDistance = lib.mkOption {
          type = lib.types.ints.between 5 32;
          default = 12;
          description = "Simulation distance in chunks (client-side)";
        };

        sound = {
          master = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Master volume (0-100%)";
          };

          music = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Music volume (0-100%)";
          };

          noteBlocks = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Note Blocks/Jukebox volume (0-100%)";
          };

          weather = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Weather volume (0-100%)";
          };

          hostile = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Hostile Mobs volume (0-100%)";
          };

          ambient = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Ambient volume (0-100%)";
          };

          voice = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 100;
            description = "Voice/Speech volume (0-100%)";
          };
        };
      };
    };

    config = let
      serverConfig = lib.mkIf cfg.enable {
        services.minecraft-server = {
          enable = true;
          eula = true;
          declarative = true;
          openFirewall = false;

          package = minecraft-server-26;

          inherit (cfg) jvmOpts;

          serverProperties =
            {
              server-port = cfg.port;
              gamemode = "survival";
              max-players = cfg.maxPlayers;
              white-list = cfg.whitelist != {};
              enforce-whitelist = cfg.whitelist != {};
              view-distance = cfg.viewDistance;
              simulation-distance = cfg.simulationDistance;
              sync-chunk-writes = true;
              enable-status = true;
            }
            // lib.getAttrs ["difficulty" "motd"] cfg;

          inherit (cfg) whitelist;
        };

        systemd.services.minecraft-server.serviceConfig =
          harden {
            ProtectHome = lib.mkForce false;
            ProtectSystem = lib.mkForce false;
            MemoryMax = lib.mkForce "4G";
          }
          // serviceDefaults {};

        networking.firewall.extraCommands = ''
          iptables -A nixos-fw -p tcp --dport ${toString cfg.port} -s ${config.networking.local.subnet} -j nixos-fw-accept
          iptables -A nixos-fw -p tcp --dport ${toString cfg.port} -s 127.0.0.1 -j nixos-fw-accept
          ip6tables -A nixos-fw -p tcp --dport ${toString cfg.port} -s ::1 -j nixos-fw-accept
        '';
      };

      clientConfig = lib.mkIf ccfg.enable {
        home-manager.users.${ccfg.user} = {
          home.file.".local/share/PrismLauncher/instances/${ccfg.instanceName}/minecraft/options.txt".source = clientOptionsFile;
        };
      };
    in
      lib.mkMerge [serverConfig clientConfig];
  };
}
