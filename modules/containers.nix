{ config, options, lib, system, ... }:
let inherit (lib) mkIf mkMerge mkOption;
inherit (lib) types mapAttrsToList mapAttrs' nameValuePair;
hostConfig = config;
allContainerNames = builtins.attrNames hostConfig.nixslib.containers;
in
{
  config = {
    containers = mapAttrs' (name: containerOptions:
      # This nameValuePair should map to `name` anyway, but I put it here to force the evaluation
      # of _hostAddressToContainerName so that conflicts will be discovered.
      nameValuePair hostConfig.nixslib._hostAddressToContainerName.${containerOptions.hostAddress} {
        autoStart = true;

        privateNetwork = true;
        inherit (containerOptions) hostAddress localAddress;

        config = {
          networking = {
            useHostResolvConf = false;
            nameservers = builtins.filter (n: n != "127.0.0.1") hostConfig.networking.nameservers;
            firewall.allowedTCPPorts = containerOptions.forwardTCPPorts;
          };
          time.timeZone = hostConfig.time.timeZone;
        };

        bindMounts =
          (map (path: {
            hostPath = path;
            mountPoint = path;
            isReadOnly = false;
          }) containerOptions.rwStraightMounts) ++
          (map (path: {
            hostPath = path;
            mountPoint = path;
            isReadOnly = true;
          }) containerOptions.roStraightMounts);
    }) hostConfig.nixslib.containers;

    networking =
      mkMerge (lib.mapAttrsToList (name: containerOptions:
        let forbiddenContainerNames = lib.subtractLists (containerOptions.allowNetworkToOtherContainers ++ [ name ]) allContainerNames;
        in
        mkMerge [
          (mkIf containerOptions.allowEgress {
            nat = {
              enable = true;
              internalInterfaces = [ "ve-${name}" ];
            };
            firewall = {
              extraCommands =
                ''
                  # Allow existing connections
                  iptables -w -A FORWARD -o ve-${name} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
                '' +
                lib.concatMapStrings (forbiddenContainerName: ''
                  # Disallow connections to other containers
                  iptables -w -A FORWARD -i ve-${name} -o ve-${forbiddenContainerName} -j nixos-fw-log-refuse
                  iptables -w -A FORWARD -i ve-${name} --dst ${hostConfig.nixslib.containers.${forbiddenContainerName}.localAddress} -j nixos-fw-log-refuse
                '') forbiddenContainerNames;
              extraStopCommands =
                ''
                  iptables -w -D FORWARD -o ve-${name} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
                '' +
                lib.concatMapStrings (forbiddenContainerName: ''
                  iptables -w -D FORWARD -i ve-${name} -o ve-${forbiddenContainerName} -j nixos-fw-log-refuse 2>/dev/null || true
                  iptables -w -D FORWARD -i ve-${name} --dst ${hostConfig.nixslib.containers.${forbiddenContainerName}.localAddress} -j nixos-fw-log-refuse 2>/dev/null || true
                '') forbiddenContainerNames;
            };
          })
          {
            nat.forwardPorts = map (port: { sourcePort = port; destination = containerOptions.localAddress; }) containerOptions.forwardTCPPorts;
            firewall.allowedTCPPorts = containerOptions.forwardTCPPorts;
          }
        ]
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
              type = with types; listOf str;
              default = [];
            };

            roStraightMounts = mkOption {
              type = with types; listOf str;
              default = [];
            };

            allowEgress = mkOption {
              type = types.bool;
              default = false;
            };

            allowNetworkToOtherContainers = mkOption {
              type = with types; listOf str;
              default = [];
            };

            localAddress = mkOption {
              type = types.str;
            };

            hostAddress = mkOption {
              type = types.str;
            };

            forwardTCPPorts = mkOption {
              type = with types; listOf int;
              default = [];
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
