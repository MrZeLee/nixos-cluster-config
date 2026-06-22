{
  config,
  pkgs,
  name,
  ...
}:
let
  # Reads the bot token / chat id from the agenix secrets at runtime (never in
  # the Nix store) and posts a message to Telegram. Best-effort: short timeout,
  # never fails the unit (so it can't hang boot or block shutdown).
  notify = pkgs.writeShellScript "telegram-host-notify" ''
    set -u
    msg="$1"
    token="$(cat ${config.age.secrets.telegram-bot-token.path} 2>/dev/null)"
    chat="$(cat ${config.age.secrets.telegram-chat-id.path} 2>/dev/null)"
    [ -n "$token" ] && [ -n "$chat" ] || exit 0
    ${pkgs.curl}/bin/curl -sS --max-time 10 \
      "https://api.telegram.org/bot''${token}/sendMessage" \
      --data-urlencode "chat_id=''${chat}" \
      --data-urlencode "text=''${msg}" >/dev/null 2>&1 || true
  '';
in
{
  # Oneshot + RemainAfterExit: ExecStart fires once at boot (the "up" message)
  # and ExecStop fires at shutdown/reboot (the "down" message). Ordered after
  # the network so the boot message can be sent, and it stops before the network
  # is torn down so the shutdown message has a chance to go out (best-effort).
  systemd.services.telegram-host-notify = {
    description = "Telegram notification on host boot and shutdown";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30s";
      TimeoutStopSec = "30s";
    };
    script = "${notify} '🟢 ${name} is up'";
    preStop = "${notify} '🔴 ${name} is shutting down'";
  };
}
