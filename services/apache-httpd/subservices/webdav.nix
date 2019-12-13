#
# apache-httpd subservice for serving WebDAV.
#
# Usage:
# services.httpd.virtualHosts = [
#     {
#         ...
#         extraSubservices = [
#             {
#                 serviceExpression = /path/to/this/services/apache-httpd/subservices/webdav.nix;
#                 config = {
#                     storageDir = ... # see other config options below
#                 };
#             }
#         ];
#     }
# ];
#
# TODO allow enabling CORS? https://github.com/keeweb/keeweb/wiki/WebDAV-Config

{ config, pkgs, lib, serverInfo, ... }:
let
webdavStateDir = with serverInfo; "${fullConfig.services.httpd.stateDir}/webdav/${vhostConfig.hostName}";
in
{
    startupScript = pkgs.writeScript "webdav_startup.sh" ''
        mkdir -m 0770 -p ${webdavStateDir}
        [ $(id -u) != 0 ] || chown ${with serverInfo.serverConfig; "${user}:${group}"} ${webdavStateDir}
    '';

    extraConfig =
        # Digest auth could help, but I can't use it with my usecase, so I'm not bothering for now.
        assert serverInfo.vhostConfig.enableSSL || config.allowPlaintextAuth;
    ''
        DAVLockDB ${webdavStateDir}/lock

        Alias ${config.baseUrl} ${config.storageDir}
        <Location ${config.baseUrl}>
            DAV On
            AuthType Basic
            AuthName "WebDAV"
            AuthBasicProvider file
            AuthUserFile ${config.authUserFile}
            Require valid-user
        </Location>
        <Directory ${config.storageDir}>
            Options +Indexes
            Require all granted
            AllowOverride None
        </Directory>
    '';

    options = with lib; {
        storageDir = mkOption {
            type = types.path;
            description = ''
                Filesystem path where WebDAV-accessible files are written/read. Should be created externally and owned
                by the user/group that the server runs as.
            '';
        };
        authUserFile = mkOption {
            type = types.path;
            description = "Path to file containing auth credentials created with htdigest. Should be readable by the server's user/group.";
        };
        baseUrl = mkOption {
            type = types.str;
            description = "Base URL under which WebDAV is enabled.";
            example = "/webdav";
        };
        allowPlaintextAuth = mkOption {
            type = types.bool;
            description = "Set to true to disable assertion failure when SSL is not enabled. This means auth will be plaintext, which is not secure for many uses.";
            default = false;
        };
    };
}
