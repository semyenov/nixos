# Comprehensive validation system for NixOS configuration
# Provides validators, conflict detection, and dependency checking

{ lib, config }:

with lib;

rec {
  # Configuration validators
  validators = {
    # Validate that a service has required dependencies
    serviceDependencies = service: deps: 
      all (dep: config.services ? ${dep} && config.services.${dep}.enable) deps;
    
    # Validate port conflicts
    checkPortConflicts = ports:
      let
        duplicates = filter (p: length (filter (x: x == p) ports) > 1) (unique ports);
      in
        if length duplicates > 0 then
          throw "Port conflict detected: ${concatStringsSep ", " (map toString duplicates)}"
        else true;
    
    # Validate path exists and is accessible
    pathExists = path:
      if builtins.pathExists path then true
      else throw "Path does not exist: ${path}";
    
    # Validate network configuration
    validateNetwork = netConfig:
      let
        validIP = ip: match "^([0-9]{1,3}\\.){3}[0-9]{1,3}$" ip != null;
        validPort = port: port >= 1 && port <= 65535;
      in
        assert validIP netConfig.address or true;
        assert validPort netConfig.port or true;
        true;
    
    # Validate memory size format
    validateMemorySize = size:
      match "^[0-9]+(K|M|G|T)?$" size != null;
    
    # Validate cron schedule
    validateCronSchedule = schedule:
      match "(@(yearly|monthly|weekly|daily|hourly)|([0-9,\\-\\*/]+\\s+){4}[0-9,\\-\\*/]+)" schedule != null;
    
    # Validate user exists
    userExists = user:
      elem user (attrNames config.users.users);
    
    # Validate group exists
    groupExists = group:
      elem group (attrNames config.users.groups);
  };
  
  # Module conflict detection
  conflicts = {
    # Check for conflicting services
    serviceConflicts = [
      { services = [ "nginx" "apache" ]; message = "nginx and apache cannot be enabled simultaneously"; }
      { services = [ "mysql" "mariadb" ]; message = "mysql and mariadb cannot be enabled simultaneously"; }
      { services = [ "pulseaudio" "pipewire" ]; message = "pulseaudio and pipewire conflict"; }
    ];
    
    # Check for conflicting configurations
    checkConflicts = config:
      let
        checkServiceConflict = conflict:
          let
            enabled = filter (s: config.services ? ${s} && config.services.${s}.enable or false) conflict.services;
          in
            if length enabled > 1 then
              throw "Service conflict: ${conflict.message}"
            else true;
      in
        all checkServiceConflict serviceConflicts;
    
    # Check for port conflicts across services
    checkPortConflicts = config:
      let
        # Collect all ports from various services
        collectPorts = {
          ssh = if config.services.openssh.enable or false then 
            config.services.openssh.ports or [ 22 ] else [];
          http = if config.services.nginx.enable or false then [ 80 443 ] else [];
          v2ray = if config.services.v2rayWithSecrets.enable or false then [ 1080 8118 ] else [];
          # Add more services as needed
        };
        allPorts = flatten (attrValues collectPorts);
        duplicates = filter (p: length (filter (x: x == p) allPorts) > 1) (unique allPorts);
      in
        if length duplicates > 0 then
          throw "Port conflicts detected on ports: ${concatStringsSep ", " (map toString duplicates)}"
        else true;
  };
  
  # Dependency resolution
  dependencies = {
    # Define service dependencies
    serviceDeps = {
      v2rayWithSecrets = [ "sops" ];
      monitoring = [ "networking" ];
      grafana = [ "prometheus" ];
      docker = [ "networking" ];
    };
    
    # Check if all dependencies are satisfied
    checkDependencies = service:
      let
        deps = dependencies.serviceDeps.${service} or [];
        missing = filter (d: !(config.services ? ${d} && config.services.${d}.enable or false)) deps;
      in
        if length missing > 0 then
          throw "Service ${service} requires: ${concatStringsSep ", " missing}"
        else true;
    
    # Resolve dependency order
    resolveDependencyOrder = services:
      let
        getDeps = s: dependencies.serviceDeps.${s} or [];
        sorted = toposort getDeps services;
      in
        if sorted ? result then sorted.result
        else throw "Circular dependency detected: ${concatStringsSep " -> " sorted.cycle}";
  };
  
  # Pre-build validation
  preBuildValidation = config: {
    # Run all validators
    validate = 
      assert conflicts.checkConflicts config;
      assert conflicts.checkPortConflicts config;
      # Add more validation checks as needed
      true;
    
    # Get validation report
    report = {
      services = attrNames (filterAttrs (n: v: v.enable or false) config.services);
      conflicts = conflicts.serviceConflicts;
      dependencies = dependencies.serviceDeps;
    };
  };
  
  # Helper to create validated options
  mkValidatedOption = { type, default ? null, description, validator ? null, ... }@args:
    mkOption (
      {
        inherit type description;
      } 
      // optionalAttrs (default != null) { inherit default; }
      // optionalAttrs (validator != null) {
        apply = value: 
          if validator value then value
          else throw "Validation failed for option: ${description}";
      }
      // removeAttrs args [ "type" "default" "description" "validator" ]
    );
  
  # Assertion builders
  assertions = {
    # Create assertion for required services
    requireService = service: message:
      {
        assertion = config.services ? ${service} && config.services.${service}.enable;
        message = message;
      };
    
    # Create assertion for required packages
    requirePackage = package: message:
      {
        assertion = elem package config.environment.systemPackages;
        message = message;
      };
    
    # Create assertion for minimum resources
    requireMinimumRAM = minGB:
      {
        assertion = config.virtualisation.memorySize or 4096 >= (minGB * 1024);
        message = "This configuration requires at least ${toString minGB}GB of RAM";
      };
    
    # Create assertion for filesystem
    requireFilesystem = fs:
      {
        assertion = any (f: f.fsType == fs) (attrValues config.fileSystems);
        message = "This configuration requires ${fs} filesystem";
      };
  };
}