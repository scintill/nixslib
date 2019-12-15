{ pkgs, config, ... }: {
    services.httpd = {
        extraConfig = ''
            CustomLog "|${pkgs.inetutils}/bin/logger -t httpd -p daemon.info" ${config.services.httpd.logFormat}
            ErrorLog syslog:daemon
        '';

        # CustomLog adds to a list of logs, so we blackhole the one that the base module will emit.
        logDir = pkgs.stdenv.mkDerivation {
            name = "null-access-log";
            buildCommand = ''
                mkdir $out
                ln -s /dev/null $out/access.log
            '';
        };
    };
}
