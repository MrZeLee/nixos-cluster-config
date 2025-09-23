{ ... }:

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
  };
}

