#
# For serving WebDAV from Apache httpd
#

# TODO allow enabling CORS? https://github.com/keeweb/keeweb/wiki/WebDAV-Config

{ config, pkgs, lib, ... }:
let
cfg = config.services.httpd-webdav;
httpdCfg = config.services.httpd;
virtualHost = config.services.httpd.virtualHostsSet.${cfg.virtualHostKey};
webdavStateDir = "${httpdCfg.stateDir}/webdav/${virtualHost.hostName}";
in
{
	imports = [
		../apache-httpd/vhostsset.nix
	];

	config = {
		services.httpd = {
			enable = true;
			virtualHostsSet.${cfg.virtualHostKey}.extraConfig =
				# Digest auth could help, but I can't use it with my usecase, so I'm not bothering for now.
				lib.mkAssert (virtualHost.enableSSL || cfg.allowPlaintextAuth) "SSL is required by httpd-webdav, unless you set allowPlaintextAuth"
				''
					DAVLockDB ${webdavStateDir}/lock

					Alias ${cfg.baseUrl} ${cfg.storageDir}
					<Location ${cfg.baseUrl}>
						DAV On
						AuthType Basic
						AuthName "WebDAV"
						AuthBasicProvider file
						AuthUserFile ${cfg.authUserFile}
						Require valid-user
					</Location>
					<Directory ${cfg.storageDir}>
						Options +Indexes
						Require all granted
						AllowOverride None
					</Directory>
				'';
		};
		systemd.services.httpd-webdav-init = {
			wantedBy = [ "multi-user.target" ];
			before = [ "httpd.service" ];
			script = ''
				mkdir -m 0770 -p ${webdavStateDir}
				[ $(id -u) != 0 ] || chown ${with httpdCfg; "${user}:${group}"} ${webdavStateDir}
			'';
		};
	};

	options = with lib; {
		services.httpd-webdav = {
			virtualHostKey = mkOption {
				type = types.str;
			};
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
    };
}
