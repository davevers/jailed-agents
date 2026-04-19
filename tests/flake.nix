{
  inputs.jailed-agents.url = "path:..";

  outputs =
    { jailed-agents, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.${system} = {
        default = jailed-agents.lib.${system}.makeJailedAgent {
          name = "env-test";
          pkg = pkgs.bashInteractive;
          configPaths = [ ];
          env = {
            MY_TEST_VAR = "hello";
            ANOTHER_VAR = "world";
          };
        };
      };
    };
}
