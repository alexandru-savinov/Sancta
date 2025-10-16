{ config, pkgs, lib, ... }:
{
  imports = [ <nixos-wsl/modules> ];
  wsl.enable = true;
  wsl.defaultUser = "nixos";

  networking.hostName = "sancta-wsl";
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ gcc zlib openssl libgcc ];

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    X11Forwarding = false;
    AllowAgentForwarding = "no";
    AllowTcpForwarding = "no";
    ClientAliveInterval = 30;
    ClientAliveCountMax = 3;
    LoginGraceTime = "20s";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowPing = true;
  };
  services.resolved.enable = false;

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "docker" "wheel" ];
    openssh.authorizedKeys.keys = lib.mkDefault [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAjXegqP28ijfIt6Uyy+x4RlJj9A/Wo/Jxc+2LyMTPm user@study-nb-prd-01"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [ git curl wget htop zip unzip jq dig ];
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 14d";
  };

  services.timesyncd.enable = true;
  services.journald = {
    storage = "persistent";
    extraConfig = "SystemMaxUse=300M";
  };
  system.stateVersion = "24.05";
}
