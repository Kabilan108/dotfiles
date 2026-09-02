{
  networking.networkmanager.ensureProfiles.profiles.MobergAnalytics = {
    connection = {
      id = "MobergAnalytics";
      type = "vpn";
      uuid = "2b74c5ba-0d05-4932-9edc-a91f4efb5a60";
      autoconnect = true;
    };

    vpn = {
      service-type = "org.freedesktop.NetworkManager.openvpn";
      auth = "SHA1";
      ca = "/home/kabilan/.config/moberg/vpn/ca.crt";
      cert = "/home/kabilan/.config/moberg/vpn/tony.crt";
      challenge-response-flags = 2;
      connection-type = "tls";
      dev = "tun";
      key = "/home/kabilan/.config/moberg/vpn/tony.key";
      remote = "71.25.106.254:1194:udp";
      remote-cert-tls = "server";
      ta = "/home/kabilan/.config/moberg/vpn/ta.key";
      ta-dir = 1;
    };

    ipv4 = {
      method = "auto";
      route1 = "10.1.10.0/24";
    };

    ipv6.method = "auto";
  };
}
