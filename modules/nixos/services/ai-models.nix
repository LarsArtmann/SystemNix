# Centralized AI model storage with unified directory structure
_: {
  flake.nixosModules.ai-models = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.ai-models;
    inherit (config.users) primaryUser;
  in {
    options.services.ai-models = {
      enable =
        lib.mkEnableOption "Centralized AI model storage — unified directory structure, env vars, and permissions"
        // {default = false;};

      baseDir = lib.mkOption {
        type = lib.types.str;
        default = "/data/ai";
        description = "Base directory for all AI model and tool data";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User owning AI model files";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Group owning AI model files";
      };

      paths = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        description = "Derived paths for all AI directories (computed from baseDir)";
        default = {
          ollama = "${cfg.baseDir}/models/ollama";
          ollama-models = "${cfg.baseDir}/models/ollama/models";
          gguf = "${cfg.baseDir}/models/gguf";
          whisper = "${cfg.baseDir}/models/whisper";
          comfyui = "${cfg.baseDir}/models/comfyui";
          jan = "${cfg.baseDir}/models/jan";
          vision = "${cfg.baseDir}/models/vision";
          image = "${cfg.baseDir}/models/image";
          embeddings = "${cfg.baseDir}/models/embeddings";
          tts = "${cfg.baseDir}/models/tts";
          huggingface = "${cfg.baseDir}/cache/huggingface";
          huggingface-hub = "${cfg.baseDir}/cache/huggingface/hub";
          huggingface-transformers = "${cfg.baseDir}/cache/huggingface/transformers";
          unsloth = "${cfg.baseDir}/workspaces/unsloth";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules =
        [
          "d ${cfg.baseDir} 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.baseDir}/models 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.baseDir}/cache 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.baseDir}/workspaces 0755 ${cfg.user} ${cfg.group} -"
        ]
        ++ map (path: "d ${path} 0755 ${cfg.user} ${cfg.group} -") [
          cfg.paths.ollama
          cfg.paths.gguf
          cfg.paths.whisper
          cfg.paths.comfyui
          cfg.paths.jan
          cfg.paths.vision
          cfg.paths.image
          cfg.paths.embeddings
          cfg.paths.tts
          cfg.paths.huggingface
          cfg.paths.huggingface-hub
          cfg.paths.huggingface-transformers
          cfg.paths.unsloth
        ]
        ++ [
          "d ${cfg.paths.ollama-models} 0775 ${cfg.user} ${cfg.group} -"
        ];

      environment.sessionVariables = {
        OLLAMA_MODELS = cfg.paths.ollama-models;
        HF_HOME = cfg.paths.huggingface;
        HUGGINGFACE_HUB_CACHE = cfg.paths.huggingface-hub;
        TRANSFORMERS_CACHE = cfg.paths.huggingface-transformers;
        LLAMA_MODEL_PATH = cfg.paths.gguf;
        UNSLOTH_MODELS = "${cfg.baseDir}/models";
      };
    };
  };
}
