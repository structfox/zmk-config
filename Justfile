## 로컬 ZMK 빌드 레시피 (#2). urob/zmk-config 의 Justfile 을 빌드 핵심만 남겨 단순화.
## 전제: `nix develop`(또는 direnv) 안에서 실행 — west/cmake/ninja/dtc/yq 가 PATH 에 있어야 함.
## 처음 한 번: `just init` → 이후 `just build right` / `just build all`.

default:
    @just --list --unsorted

config := absolute_path('config')
build := absolute_path('.build')
out := absolute_path('firmware')

build_matrix := "build.yaml"

# build.yaml 파싱: 표현식(expr)으로 타겟 필터 (예: right, left, dongle, all)
_parse_targets $expr:
    #!/usr/bin/env bash
    attrs="[.board, .shield, .snippet, .\"artifact-name\", .\"cmake-args\"]"
    filter="(($attrs | map(. // [.]) | combinations), ((.include // {})[] | $attrs)) | join(\",\")"
    echo "$(yq -r "$filter" {{build_matrix}} | grep -v "^," | grep -i "${expr/#all/.*}")"

# 단일 board+shield 빌드
_build_single $board $shield $snippet $artifact cmake_args *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${artifact:-${shield:+${shield// /+}-}${board//\//_}}"
    build_dir="{{ build / '$artifact' }}"

    echo "Building $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} ${snippet:+-S "$snippet"} -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"} {{ cmake_args }}

    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# 매칭되는 모든 타겟 빌드 (expr: right / left / dongle / all)
build expr *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just build_matrix={{build_matrix}} _parse_targets {{ expr }})
    [[ -z $targets ]] && echo "매칭 타겟 없음. 중단." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet artifact cmake_args; do
        just _build_single "$board" "$shield" "$snippet" "$artifact" "$cmake_args" {{ west_args }}
    done

# west 워크스페이스 1회 초기화 (zmk/zephyr/모듈 다운로드, 수 GB)
init:
    west init -l config
    west update --fetch-opt=--filter=blob:none
    west zephyr-export

# 모듈/zephyr 업데이트 (west.yml 변경 후 실행)
update:
    west update --fetch-opt=--filter=blob:none

# 빌드 타겟 목록
list:
    @just build_matrix={{build_matrix}} _parse_targets all \
        | sed 's|[@/][^,]*,|,|' \
        | sed 's|\([^,]*\),\([^,]\+\),.*|\2|' \
        | sed 's|\([^,]*\),,.*|\1|' \
        | sort | column

# 빌드 캐시/산출물 삭제
clean:
    rm -rf {{ build }} {{ out }}
