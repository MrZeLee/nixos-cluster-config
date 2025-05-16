{ ... }:

{
  age.secrets.k3s-token = {
    file = ./secrets/k3s-token.age;
    owner = "root";
    mode = "0400";
  };
}

