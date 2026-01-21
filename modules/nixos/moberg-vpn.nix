{ config, ... }:
{
  # Secrets decrypted at activation (owned by root for openvpn)
  age.secrets.moberg-vpn-key.file = ../../secrets/moberg-vpn/key.age;
  age.secrets.moberg-vpn-ta.file = ../../secrets/moberg-vpn/ta.age;
  age.secrets.moberg-vpn-cert.file = ../../secrets/moberg-vpn/cert.age;
  age.secrets.moberg-vpn-ca.file = ../../secrets/moberg-vpn/ca.age;

  services.openvpn.servers.moberg = {
    autoStart = true;
    config = ''
      dev tun
      persist-tun
      persist-key
      auth SHA1
      tls-client
      client
      resolv-retry infinite
      remote 71.25.106.254 1194 udp
      ca ${config.age.secrets.moberg-vpn-ca.path}
      key ${config.age.secrets.moberg-vpn-key.path}
      cert ${config.age.secrets.moberg-vpn-cert.path}
      tls-auth ${config.age.secrets.moberg-vpn-ta.path} 1
      remote-cert-tls server
      route 10.1.10.0 255.255.255.0

      # Keep connection alive
      keepalive 5 30
    '';
  };
}
