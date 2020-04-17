{ config, options, lib, system, ... }:
let inherit (lib) mkIf mkMerge mkOption;
inherit (lib) types mapAttrsToList mapAttrs' nameValuePair;
hostConfig = config;
in
{
  config = {
    containers = mapAttrs' (name: containerOptions:
      # Typically this nameValuePair will map to `name`, but I put it here to force the evaluation
      # of _hostAddressToContainerName so that conflicts will be discovered.
      nameValuePair hostConfig.nixslib._hostAddressToContainerName.${containerOptions.hostAddress} {
        autoStart = true;

        privateNetwork = true;
        inherit (containerOptions) hostAddress localAddress;

        config = {
          networking = {
            useHostResolvConf = false;
            nameservers = builtins.filter (n: n != "127.0.0.1") hostConfig.networking.nameservers;
          };
        };

        bindMounts = map (path: {
          hostPath = path;
          mountPoint = path;
          isReadOnly = false;
        }) containerOptions.rwStraightMounts;
    }) hostConfig.nixslib.containers;

    networking.nat = mkMerge (lib.mapAttrsToList (name: containerOptions:
      mkIf containerOptions.allowEgress {
        enable = true;
        internalInterfaces = ["ve-${name}"];
      }
    ) hostConfig.nixslib.containers);

    # Track IP addresses, to detect conflicts.
    nixslib._hostAddressToContainerName = mkMerge (lib.mapAttrsToList (name: containerOptions: {
      ${containerOptions.hostAddress} = name;
    }) hostConfig.nixslib.containers);
  };

  options = {
    nixslib.containers = mkOption {
      default = {};
      type = types.attrsOf (types.submodule
        {
          options = {
            rwStraightMounts = mkOption {
              type = types.listOf types.str;
              default = [];
            };

            allowEgress = mkOption {
              type = types.bool;
              default = false;
            };

            localAddress = mkOption {
              type = types.str;
            };

            hostAddress = mkOption {
              type = types.str;
            };
          };
        }
      );
    };

    # Not part of the public interface.
    nixslib._hostAddressToContainerName = mkOption {
      type = types.attrsOf types.str;
    };
  };
}
