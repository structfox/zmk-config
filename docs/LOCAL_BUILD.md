# 로컬 빌드 환경 (#2)

CI(GitHub Actions)에만 의존하지 않고 **로컬에서 수 초~분 단위로 빌드 + 로그 캡처**하기 위한 셋업.
urob/zmk-config 의 nix 기반 워크플로를 빌드 핵심만 남겨 단순화했다.

> 현재 이 기기엔 nix·west·Zephyr SDK 가 설치돼 있지 않다. 아래 **1회 설치**는 직접 실행해야 한다
> (toolchain 다운로드가 수 GB라 자동화하지 않음). `flake.nix`/`Justfile` 은 아직 로컬 검증 전이므로
> 첫 `nix develop` / `just init` 때 오류가 나면 알려주면 바로 잡는다.

## 권장 경로: nix (재현성 ↑, macOS에서 ZMK toolchain 가장 안정적)

### 1회 설치
```bash
# 1) nix 설치 (Determinate Systems 인스톨러 권장 — flakes 기본 활성화)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2) (선택) direnv 설치 — 디렉터리 진입 시 자동 셸 활성화
brew install direnv   # 그리고 셸 rc 에 `eval "$(direnv hook zsh)"` 추가
```

### 매번
```bash
cd <이 repo>
nix develop            # direnv 쓰면 자동 (최초 1회 `direnv allow`)

just init              # west 워크스페이스 초기화 (zmk/zephyr/모듈 clone, 수 GB·최초 1회)
just build right       # charybdis_right 빌드 → firmware/charybdis_right-nice_nano.uf2
just build dongle      # 동글(키맵·HRM·auto-layer 반영분)
just build all         # 좌/우/동글 전부
just list              # 빌드 타겟 목록
```
`west.yml` 을 바꾼 뒤에는 `just update` 로 모듈을 갱신한다.

## 디버그 로그 캡처 (간헐 멈춤 원인 규명용)

`boards/shields/charybdis/charybdis.conf` 의 두 줄 주석을 해제하면 USB 시리얼 로그가 켜진다:
```
CONFIG_ZMK_LOG_LEVEL_DBG=y
CONFIG_ZMK_USB_LOGGING=y
```
→ `just build right` 로 빌드·플래시 후, 오른쪽을 USB로 꽂고 시리얼 콘솔(`screen`/`tio` 등)로
죽는 순간을 관찰한다. (로그가 뚝 멈춤=행 / `pmw3610`·SPI 에러=드라이버·HW / `disconnected`=BLE)

## nix 없이 가려면 (대안, 비권장)

`west` 를 pip 으로 설치하고 Zephyr SDK(arm-zephyr-eabi)를 수동 설치한 뒤 같은 `just init`/`just build`
를 쓸 수 있다. 다만 macOS에서 SDK·의존성 버전 맞추기가 까다로워 nix 경로를 권한다.
참고: <https://zmk.dev/docs/development/local-toolchain/setup>
