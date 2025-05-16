{ ... }:

{
  age.secrets.k3s-token = {
    file = ./secrets/k3s-token.age;
    owner = "root";
    mode = "0400";
    identityPaths = "/etc/agenix/age-key.txt";
  };
}

