_:

{
  age = {
    secrets.k3s-token = {
      file = ./secrets/k3s-token.age;
      owner = "root";
      mode = "0400";
    };
    secrets.github-token = {
      file = ./secrets/github-token.age;
      owner = "root";
      mode = "0400";
    };
    secrets.telegram-bot-token = {
      file = ./secrets/telegram-bot-token.age;
      owner = "root";
      mode = "0400";
    };
    secrets.telegram-chat-id = {
      file = ./secrets/telegram-chat-id.age;
      owner = "root";
      mode = "0400";
    };
    secrets.headscale-domain = {
      file = ./secrets/headscale-domain.age;
      owner = "root";
      mode = "0400";
    };
  };
}
