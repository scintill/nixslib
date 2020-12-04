{ pkgs, ... }:
let
  ianaPortsListNix = pkgs.stdenv.mkDerivation {
    name = "iana-ports-list-nix";
    buildCommand = ''
      mkdir $out
      cd $out
      ${pkgs.gawk}/bin/awk -f ${./process_iana.awk} < ${pkgs.iana_etc}/etc/services
    '';
  };
in {
  tcp = import "${ianaPortsListNix}/tcp_ports.nix";
  udp = import "${ianaPortsListNix}/udp_ports.nix";
}
