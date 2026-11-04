# Unlock the LUKS root over SSH at boot. The systemd initrd brings up
# Ethernet with DHCP and runs sshd on lib/fleet.nix initrdUnlock.port. Logging
# in as root answers the passphrase prompt and does nothing else. Only the
# YubiKey logins of hosts allowed into tleilax (jacurutu) are authorized. The
# HDMI console asks for the passphrase at the same time.
#
# u-boot's extlinux loader can't append secrets to the initrd, and
# boot.initrd.network.ssh.hostKeys would put the private key in the
# world-readable Nix store. So the boot environment's host key sits on the
# unencrypted boot partition, where an appended key would end up anyway, and
# a unit copies it in before sshd starts. It is not the system's host key,
# which stays on the encrypted root.
{
  config,
  utils,
  ...
}:
let
  fleet = import ../../lib/fleet.nix;
  thisHost = config.networking.hostName;
  unlock = fleet.hosts.${thisHost}.initrdUnlock;
  humanKeys = builtins.concatMap (name: fleet.hosts.${name}.keys.human) (fleet.accessorsOf thisHost);

  bootDevice = config.disko.devices.disk.ssd.content.partitions.boot.device;
  bootDeviceUnit = "${utils.escapeSystemdPath bootDevice}.device";
  keyOnBoot = "initrd-ssh/ssh_host_ed25519_key";
  keyMount = "/run/initrd-ssh-key";
in
{
  boot.initrd.network.enable = true;

  boot.initrd.network.ssh = {
    enable = true;
    inherit (unlock) port;
    ignoreEmptyHostKeys = true;
    authorizedKeys = map (key: "restrict,pty ${key}") humanKeys;
    extraConfig = ''
      HostKey /etc/ssh/ssh_host_ed25519_key
      AllowAgentForwarding no
      AllowTcpForwarding no
      AllowStreamLocalForwarding no
      PermitTunnel no
    '';
  };

  boot.initrd.systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent";

  boot.initrd.supportedFilesystems.vfat = true;

  boot.initrd.systemd.services.initrd-ssh-host-key = {
    description = "Copy the boot SSH host key from the boot partition";
    requiredBy = [ "sshd.service" ];
    before = [ "sshd.service" ];
    requires = [ bootDeviceUnit ];
    after = [ bootDeviceUnit ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p ${keyMount} /etc/ssh
      mount -t vfat -o ro,umask=0077 ${bootDevice} ${keyMount}
      trap 'umount ${keyMount}' EXIT
      install -m 0600 ${keyMount}/${keyOnBoot} /etc/ssh/ssh_host_ed25519_key
    '';
  };
}
