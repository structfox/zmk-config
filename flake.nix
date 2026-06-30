{
  # 로컬 ZMK 빌드용 nix devShell (#2).
  # urob/zmk-config 의 flake 를 자체 완결형으로 단순화 — keymap-drawer/dts-format/
  # dts-linter 등 부가 도구는 제외하고 "빌드에 필요한 toolchain" 만 제공한다.
  #
  # 사용법 (자세히는 docs/LOCAL_BUILD.md):
  #   nix develop      # 또는 direnv allow
  #   just init        # west 워크스페이스 1회 초기화 (수 GB 다운로드)
  #   just build right # charybdis_right 빌드 → firmware/*.uf2
  #
  # zephyr 버전은 ZMK main 이 핀한 v4.1.0+zmk-fixes 와 맞춘다.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    zephyr.url = "github:zmkfirmware/zephyr/v4.1.0+zmk-fixes";
    zephyr.flake = false;

    zephyr-nix.url = "github:nix-community/zephyr-nix";
    zephyr-nix.inputs.zephyr.follows = "zephyr";
    zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, zephyr-nix, ... }: let
    systems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        zephyr = zephyr-nix.packages.${system};
      in {
        default = pkgs.mkShellNoCC {
          packages = [
            zephyr.pythonEnv
            (zephyr.sdk-0_16.override { targets = ["arm-zephyr-eabi"]; })

            pkgs.cmake
            pkgs.dtc
            pkgs.gcc
            pkgs.ninja

            pkgs.just
            pkgs.yq # python-yq (Justfile 의 build.yaml 파싱에 필요)
          ];

          env = {
            PYTHONPATH = "${zephyr.pythonEnv}/${zephyr.pythonEnv.sitePackages}";
          };

          shellHook = ''
            export ZMK_BUILD_DIR=$(pwd)/.build;
            export ZMK_SRC_DIR=$(pwd)/zmk/app;
          '';
        };
      }
    );
  };
}
