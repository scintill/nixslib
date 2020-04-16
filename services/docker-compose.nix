{ projectName, composeFilePaths, build ? false, pkgs }:
assert (builtins.length composeFilePaths) > 0;
let dc = "${pkgs.docker-compose}/bin/docker-compose --project-directory ${builtins.dirOf (builtins.head composeFilePaths)}";
inherit (pkgs.lib) mkIf;
in
{
  # https://community.hetzner.com/tutorials/docker-compose-as-systemd-service#step-2---create-the-systemd-service-template
  requires = ["docker.service" "network-online.target"];
  after = ["docker.service" "network-online.target"];
  wantedBy = ["multi-user.target"];
  serviceConfig = {
    Type = "simple";
    TimeoutStartSec = "15min";
    Restart = "always";

    Environment = [
      "COMPOSE_PROJECT_NAME=${projectName}"
      "COMPOSE_FILE=${builtins.concatStringsSep ":" composeFilePaths}"
    ];

    ExecStartPre = mkIf build [
      "${dc} pull --quiet --ignore-pull-failures"
      "${dc} build --pull"
    ];

    ExecStart = "${dc} up --remove-orphans";

    ExecStop = "${dc} down --remove-orphans";

    ExecReload = mkIf build [
      "${dc} pull --quiet --ignore-pull-failures"
      "${dc} build --pull"
    ];

    StandardOutput = "null";
  };
}
