{ lib, config, modulesPath, ... }:
let
inherit (lib) mkOption mkForce;
inherit (lib) types;
in
{
    config.services.httpd.virtualHosts = lib.mkAfter (lib.attrsets.attrValues config.services.httpd.virtualHostsSet);

    options = {
        services.httpd.virtualHostsSet = mkOption {
            type = types.attrsOf (types.submodule {
                options = import (modulesPath+"/services/web-servers/apache-httpd/per-server-options.nix") {
                    inherit lib;
                    forMainServer = false;
                };
            });
            description = ''
                Modules that want to build a vhost together can assign to this property, and the merged vhost definition
                will be appended to the virtualHosts list.
            '';
        };
    };
}
