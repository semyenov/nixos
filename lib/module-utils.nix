# Module utilities library
# Provides common helper functions for creating consistent NixOS modules

{ lib }:

with lib;

rec {
  # Create a standard module option with enhanced documentation
  mkModuleOption =
    { type
    , default ? null
    , example ? null
    , description
    , ...
    }@args: mkOption (
      {
        inherit type description;
      }
      // optionalAttrs (default != null) { inherit default; }
      // optionalAttrs (example != null) { inherit example; }
      // removeAttrs args [ "type" "default" "example" "description" ]
    );

  # Create a port option with validation
  mkPortOption = { default, description ? "Port number", example ? null }:
    mkModuleOption
      {
        type = lib.types.ints.u16; # Port number type (0-65535)
        inherit default description;
      } // optionalAttrs (example != null) { inherit example; };

  # Create a path option with validation
  mkPathOption = { default ? null, description, example ? null }:
    mkModuleOption
      {
        type = lib.types.path;
        inherit description;
      } // optionalAttrs (default != null) { inherit default; }
    // optionalAttrs (example != null) { inherit example; };

  # Create a service enable option with enhanced description
  mkServiceEnableOption = name: description:
    mkEnableOption "${name} - ${description}";

  # Create a list of strings option
  mkStringListOption = { default ? [ ], description, example ? null }:
    mkModuleOption
      {
        type = lib.types.listOf lib.types.str;
        inherit default description;
      } // optionalAttrs (example != null) { inherit example; };

  # Create an enum option with validation
  mkEnumOption = { values, default, description, example ? null }:
    mkModuleOption
      {
        type = lib.types.enum values;
        inherit default description;
      } // optionalAttrs (example != null) { inherit example; };

  # Create a percentage option (0-100)
  mkPercentageOption = { default, description }:
    mkModuleOption {
      type = lib.types.ints.between 0 100;
      inherit default description;
    };

  # Create a memory size option (with units)
  mkMemoryOption = { default ? null, description, example ? "2G" }:
    mkModuleOption
      {
        type = lib.types.str;
        inherit description example;
      } // optionalAttrs (default != null) { inherit default; };

  # Create a schedule option (systemd timer format)
  mkScheduleOption = { default ? "daily", description ? "Schedule in systemd timer format" }:
    mkModuleOption {
      type = lib.types.str;
      inherit default description;
      example = "weekly";
    };

  # Create an assertion with a descriptive message
  mkAssertion = condition: message: {
    assertion = condition;
    message = "Configuration error: ${message}";
  };

  # Check if a service is enabled
  serviceEnabled = config: service:
    config.services ? ${service} && config.services.${service}.enable or false;

  # Check if a module is enabled
  moduleEnabled = config: path:
    let
      parts = splitString "." path;
      getValue = cfg: p:
        if length p == 0 then cfg
        else if cfg ? ${head p} then getValue cfg.${head p} (tail p)
        else false;
    in
    getValue config parts != false && (getValue config parts).enable or false;

  # Create a submodule option
  mkSubmoduleOption = { options, description, default ? { } }:
    mkModuleOption {
      type = lib.types.submodule { inherit options; };
      inherit default description;
    };

  # Create options for a time window
  mkTimeWindowOptions =
    { startDefault ? "02:00"
    , endDefault ? "05:00"
    , description ? "Time window"
    }: {
      start = mkModuleOption {
        type = lib.types.str;
        default = startDefault;
        description = "${description} start time (HH:MM format)";
        example = "03:00";
      };
      end = mkModuleOption {
        type = lib.types.str;
        default = endDefault;
        description = "${description} end time (HH:MM format)";
        example = "06:00";
      };
    };

  # Create rate limiting options
  mkRateLimitOptions =
    { limitDefault ? "1/s"
    , burstDefault ? 3
    , prefix ? ""
    }: {
      "${prefix}limit" = mkModuleOption {
        type = lib.types.str;
        default = limitDefault;
        description = "Rate limit (e.g., '1/s', '10/m')";
        example = "5/s";
      };
      "${prefix}burst" = mkModuleOption {
        type = lib.types.int;
        default = burstDefault;
        description = "Burst size for rate limiting";
        example = 5;
      };
    };

  # Merge multiple configurations with priority
  mkMergedConfig = configs:
    mkMerge (map (cfg: mkIf cfg.condition cfg.config) configs);

  # Create a validated integer range option
  mkIntRangeOption = { min, max, default, description }:
    mkModuleOption {
      type = lib.types.ints.between min max;
      inherit default description;
      example = default;
    };

  # Create network CIDR option
  mkNetworkOption = { default ? null, description, example ? "192.168.1.0/24" }:
    mkModuleOption
      {
        type = lib.types.str;
        inherit description example;
      } // optionalAttrs (default != null) { inherit default; };

  # Helper to create consistent systemd service configurations
  mkSystemdService =
    { description
    , after ? [ ]
    , wants ? [ ]
    , wantedBy ? [ "multi-user.target" ]
    , serviceConfig
    , ...
    }@args: {
      inherit description wantedBy;
    } // optionalAttrs (after != [ ]) { inherit after; }
    // optionalAttrs (wants != [ ]) { inherit wants; }
    // { inherit serviceConfig; }
    // removeAttrs args [ "description" "after" "wants" "wantedBy" "serviceConfig" ];

  # Validation helpers
  validators = {
    # Validate email format
    isEmail = str: match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$" str != null;

    # Validate IPv4 address
    isIPv4 = str: match "^([0-9]{1,3}\\.){3}[0-9]{1,3}$" str != null;

    # Validate IPv6 address (simplified)
    isIPv6 = str: match "^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$" str != null;

    # Validate port range
    isValidPort = port: port >= 1 && port <= 65535;

    # Validate systemd timer format
    isSystemdTimer = str:
      elem str [ "minutely" "hourly" "daily" "weekly" "monthly" "yearly" ] ||
      match "^[*0-9,/-]+( [*0-9,/-]+){0,4}$" str != null ||
      match "^[A-Za-z]{3} [*0-9,/-]+ [*0-9,/-]+:[*0-9,/-]+:[*0-9,/-]+$" str != null;
  };

  # Common assertions
  assertions = {
    # Assert that required services are enabled
    requireServices = config: services:
      map
        (service: mkAssertion
          (serviceEnabled config service)
          "${service} service must be enabled"
        )
        services;

    # Assert mutually exclusive options
    mutuallyExclusive = options: selected:
      let
        active = filter (opt: opt.value or false) options;
      in
      mkAssertion
        (length active <= 1)
        "Options ${concatStringsSep ", " (map (o: o.name) options)} are mutually exclusive";

    # Assert dependency chain
    requiresOption = option: dependency: message:
      mkAssertion
        (!option || dependency)
        message;
  };

  # Custom types for common configurations
  types = {
    # Network configuration type
    networkConfig = lib.types.submodule {
      options = {
        address = mkOption {
          type = lib.types.str;
          description = "Network address";
          example = "192.168.1.100";
        };
        port = mkOption {
          type = lib.types.port;
          description = "Network port";
          example = 8080;
        };
        protocol = mkOption {
          type = lib.types.enum [ "tcp" "udp" "both" ];
          default = "tcp";
          description = "Network protocol";
        };
      };
    };

    # Service configuration type
    serviceConfig = lib.types.submodule {
      options = {
        enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable the service";
        };
        port = mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Service port";
        };
        user = mkOption {
          type = lib.types.str;
          default = "nobody";
          description = "User to run the service as";
        };
        group = mkOption {
          type = lib.types.str;
          default = "nogroup";
          description = "Group to run the service as";
        };
      };
    };

    # Time window type
    timeWindow = lib.types.submodule {
      options = mkTimeWindowOptions { };
    };

    # Cron schedule type
    cronSchedule = lib.types.strMatching "(@(yearly|monthly|weekly|daily|hourly)|([0-9,\\-\\*/]+\\s+){4}[0-9,\\-\\*/]+)";

    # File path that must exist
    existingPath = lib.types.addCheck lib.types.path (p: builtins.pathExists p);

    # Positive integer
    positiveInt = lib.types.ints.positive;

    # Memory size (with units)
    memorySize = lib.types.strMatching "[0-9]+(K|M|G|T)?";

    # URL type
    url = lib.types.strMatching "^https?://.*";

    # Email type
    email = lib.types.strMatching "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$";

    # CIDR network
    cidr = lib.types.strMatching "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$";

    # Domain name
    domain = lib.types.strMatching "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$";
  };

  # Documentation helpers
  mkDocumentation = {
    # Generate option documentation
    generateOptionDocs = options:
      concatStringsSep "\n" (
        mapAttrsToList
          (name: opt: ''
            ## ${name}
            ${opt.description or "No description"}
            ${optionalString (opt ? default) "Default: `${toString opt.default}`"}
            ${optionalString (opt ? example) "Example: `${toString opt.example}`"}
          '')
          options
      );

    # Create a module header comment
    mkModuleHeader = { name, description, maintainer ? null, dependencies ? [ ] }:
      ''
        # ${name}
        # ${description}
        ${optionalString (maintainer != null) "# Maintainer: ${maintainer}"}
        ${optionalString (dependencies != []) "# Dependencies: ${concatStringsSep ", " dependencies}"}
        ${optionalString (dependencies != []) "# "}
      '';
  };
}

