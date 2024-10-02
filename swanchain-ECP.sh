#!/bin/bash

# 색상 정의
BOLD='\033[1m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

echo -e "${GREEN}SWAN ECP노드 설치를 시작합니다.${NC}"

# root 사용자로 실행 중인지 확인
if [ "$(id -u)" != "0" ]; then
    echo "${RED}이 스크립트는 root 사용자 권한으로 실행해야 합니다.${NC}"
    echo "${YELLOW}윈도우 사용자라면 'sudo -i' 명령어를 사용하여 root 사용자로 전환한 후, 다시 이 스크립트를 실행해 주세요.${NC}"
    exit 1
fi

# 현재 디렉토리 확인
current_dir=$(pwd)
echo -e "${YELLOW}현재 디렉토리: ${current_dir}${NC}"

# 사용자에게 작업 디렉토리 입력 받기
read -p "위 정보를 바탕으로 작업 디렉토리를 입력하세요 (예: /home/user/swan-ecp or /root/swan-ecp): " work

# 작업 디렉토리가 기존에 존재하는 경우 삭제
if [ -d "$work" ]; then
    echo -e "${RED}기존 디렉토리 '$work'가 존재합니다. 삭제합니다...${NC}"
    rm -rf "$work"
fi

# 작업 디렉토리 생성
mkdir -p "$work"
echo -e "${GREEN}디렉토리 '$work'가 생성되었습니다.${NC}"

# 생성한 작업 디렉토리로 이동
cd "$work" || { echo "${RED}디렉토리 이동 실패!${NC}"; exit 1; }
echo -e "${GREEN}작업 디렉토리로 이동했습니다: ${work}${NC}"

# Docker 설치 여부 확인 함수
function check_docker_installation() {
    if ! command -v docker &> /dev/null; then
        echo "${YELLOW}Docker가 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"

        # Docker 설치
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce

        # Docker 서비스 시작 및 부팅 시 자동 실행 설정
        systemctl start docker
        systemctl enable docker

        echo "${GREEN}Docker 설치가 완료되었습니다.${NC}"
    else
        echo "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
    fi
}

# 필수 패키지 설치
echo "${YELLOW}필수 패키지 설치 중...${NC}"
apt update
apt install -y curl wget git apt-transport-https ca-certificates software-properties-common
echo -e "${YELLOW}Git을 설치합니다...${NC}"
sudo apt install -y git

# 메인 메뉴 함수
function main_menu() {
    while true; do
        clear
        echo "${RED}스크립트를 종료하려면 ctrl + C를 누르세요.${NC}"
        echo -e "${YELLOW}대시보드는 이링크로 들어가세요: https://provider.swanchain.io/rankings/ecp ${NC}"
        echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
        echo "실행할 작업을 선택하세요:"
        echo "1) 노드 설치"
        echo "2) ZK 작업 목록 보기"
        echo "3) 노드 로그 조회"
        echo "4) 노드 재시작"
        echo "5) 실행 중인 작업 목록 보기"
        echo "6) resource-exporter 로그 확인"
        echo "7) ECP 환경 설치 여부 확인"
        echo "0) 종료"
        read -p "${YELLOW}옵션을 입력하세요 (0-7): ${NC}" choice

        case $choice in
            1)
                install_node
                ;;
            2)
                view_zk_task_list
                ;;
            3)
                query_node_logs
                ;;
            4)
                restart_node
                ;;
            5)
                view_running_tasks
                ;;
            6)
                check_resource_exporter_logs
                ;;
            7)
                verify_ecp_installation
                ;;
            0)
                echo "${GREEN}스크립트를 종료합니다...${NC}"
                exit 0
                ;;
            *)
                echo "${RED}잘못된 선택입니다.${NC}"
                ;;
        esac

        read -p "${YELLOW}메인 메뉴로 돌아가려면 아무 키나 누르세요...${NC}"
    done
}

# resource-exporter 로그 확인 함수
function check_resource_exporter_logs() {
    echo "${GREEN}resource-exporter 로그를 확인 중입니다...${NC}"
    docker logs -f resource-exporter
}

# ECP 환경 설치 여부 확인 함수
function verify_ecp_installation() {
    # 현재 공용 IP 주소 확인
    current_ip=$(curl -s ifconfig.me)
    echo "${YELLOW}현재 공용 IP 주소: ${GREEN}$current_ip${NC}"

    # 공용 IP 주소 입력받기
    read -p "${YELLOW}공용 IP 주소를 입력하세요 (기본값: $current_ip): ${NC}" public_ip
    public_ip=${public_ip:-$current_ip}  # 기본값으로 현재 IP를 사용

    # 포트 번호 입력받기
    read -p "${YELLOW}포트 번호를 입력하세요 (기본값: 9085): ${NC}" port

    # ECP 환경 설치 여부 확인
    echo "${GREEN}ECP 환경 설치 여부를 확인 중입니다...${NC}"
    curl -s http://$public_ip:$port/api/v1/computing/cp
}

# 노드 설치 함수
function install_node() {
    echo "${GREEN}setup.sh 스크립트를 다운로드하고 실행 중입니다...${NC}"
    curl -fsSL https://raw.githubusercontent.com/swanchain/go-computing-provider/releases/ubi/setup.sh | bash

    mkdir /root/V28_PARAMS_PATH  
    export PARENT_PATH="/root/V28_PARAMS_PATH"

    echo "${YELLOW}다운로드할 매개 변수 파일을 선택하세요:${NC}"
    echo "1) 512MiB 매개 변수"
    echo "2) 32GiB 매개 변수"
    read -p "${YELLOW}옵션을 입력하세요 (1 또는 2): ${NC}" param_choice

    case $param_choice in
        1)
            echo "${GREEN}fetch-param-512.sh 스크립트를 다운로드하고 실행 중입니다...${NC}"
            curl -fsSL https://raw.githubusercontent.com/swanchain/go-computing-provider/releases/ubi/fetch-param-512.sh | bash
            ;;
        2)
            echo "${GREEN}fetch-param-32.sh 스크립트를 다운로드하고 실행 중입니다...${NC}"
            curl -fsSL https://raw.githubusercontent.com/swanchain/go-computing-provider/releases/ubi/fetch-param-32.sh | bash
            ;;
        *)
            echo "${RED}잘못된 선택입니다.${NC}"
            ;;
    esac

    echo "${GREEN}computing-provider를 다운로드 중입니다...${NC}"
    wget https://github.com/swanchain/go-computing-provider/releases/download/v0.6.2/computing-provider

    echo "${GREEN}computing-provider에 권한을 부여합니다...${NC}"
    chmod -R 755 computing-provider

    read -p "${YELLOW}공용 IP 주소를 입력하세요: ${NC}" public_ip
    read -p "${YELLOW}사용할 포트 번호를 입력하세요 (기본값 9085): ${NC}" port
    port=${port:-9085}
    read -p "${YELLOW}노드 이름을 입력하세요: ${NC}" node_name

    echo "${GREEN}ECP 저장소를 초기화 중입니다...${NC}"
    ./computing-provider init --multi-address=/ip4/$public_ip/tcp/$port --node-name=$node_name

    echo "${YELLOW}지갑 작업을 선택하세요:${NC}"
    echo "1) 새로운 지갑 주소 생성"
    echo "2) 개인 키로 지갑 가져오기"
    echo -e "${YELLOW}어느 방식을 선택하든 Swanchain에 메인넷 ETH가 소량 필요합니다.${NC}"
    echo -e "${YELLOW}https://bridge.swanchain.io/ 에서 약 0.01이상의 메인넷ETH를 브릿징 해주세요.${NC}"
    echo -e "${YELLOW}메타마스크를 이용시GASFEE가 높게 나옵니다. Rabby wallet을 이용해서 기위를 0.0015로 고정하세요.${NC}"
    read -p "${GREEN}옵션을 입력하세요 (1 또는 2): ${NC}" wallet_choice

    case $wallet_choice in
        1)
            echo "${GREEN}새로운 지갑 주소를 생성 중입니다...${NC}"
            ./computing-provider wallet new
            ;;
        2)
            echo "${GREEN}개인 키로 지갑을 가져옵니다...${NC}"
            ./computing-provider wallet import
            ;;
        *)
            echo "${RED}잘못된 선택입니다.${NC}"
            ;;
    esac
            
    # ECP 계정 초기화
    echo -e "${GREEN}보안을 위해 모든 지갑은 다르게 적어주세요.${NC}"
    echo -e "${GREEN}https://bridge.swanchain.io/ 에서 약 0.01이상의 메인넷ETH를 브릿징 해주세요.${NC}"
    echo -e "${GREEN}ownerAddress: 이것은 CP 계정의 소유자 계정입니다. 소유자는 다중 주소, 근로자 주소, 수혜자 주소와 같은 계정 정보를 변경할 수 있는 권한이 있습니다.${NC}"
    echo -e "${GREEN}workerAddress: 이것은 증명을 제출하는데 사용되는 실제 작업주소입니다. 증명을 제출할 때 가스 요금을 지불하기 위해 특정 양의 ETH로 자금을 조달해야 합니다.${NC}"
    echo -e "${GREEN}beneficiaryAddress: CP 계정의 모든 수익이 전송되는 주소입니다. 자금을 받는 데만 사용됩니다. 보안상의 이유로 격리를 유지하기 위해 서버에 개인 키를 저장해서는 안 됩니다..${NC}"
    echo -e "${GREEN}https://docs.swanchain.io/bulders/computing-provider/edge-computing-provider-ecp/ecp-faq#q-what-are-owneraddress-workeraddress-and-beneficiaryaddress${NC}"
    read -p "${YELLOW}오너 월렛 주소를 입력하세요: ${NC}" owner_address
    read -p "${YELLOW}워커 월렛 주소를 입력하세요: ${NC}" worker_address
    read -p "${YELLOW}리워드 월렛 주소를 입력하세요: ${NC}" beneficiary_address

    echo "${GREEN}ECP 계정을 초기화합니다...${NC}"
    ./computing-provider account create \
        --ownerAddress $owner_address \
        --workerAddress $worker_address \
        --beneficiaryAddress $beneficiary_address \
        --task-types 1,2,4
        
    # SWANCECP 담보 추가
    read -p "${YELLOW}SWANC 토큰의 담보를 지급할 지갑주소를 입력하세요 메인넷SWANC 토큰이 100개이상 필요합니다.: ${NC}" collateral_address
    echo -e "${GREEN}https://docs.swanchain.io/swan-chain-campaign/swan-chain-mainnet/free-tier-and-special-credit-programs${NC}"
    echo -e "${GREEN}https://faucet.swanchain.io${NC}"
    read -p "${YELLOW}담보로 추가할 SWANC 양을 입력하세요 (100개 이상이 필요합니다): ${NC}" collateral_amount
    echo "${GREEN}SWANCECP 담보를 추가 중입니다...${NC}"
    ./computing-provider collateral add --ecp --from $collateral_address $collateral_amount

    # SwanETHSequencer 계정에 입금
    read -p "${YELLOW}해당사이트에서 메인넷으로 ETH를 브릿지 해주세요.:https://bridge.swanchain.io/${NC}"
    read -p "${YELLOW}SwanETHSequencer 계정에 입금할 EVM 지갑 주소를 입력하세요: ${NC}" sequencer_address
    read -p "${YELLOW}입금할 ETH 양을 입력하세요 (0.01개 이상 추천): ${NC}" eth_amount

    echo "${GREEN}SwanETHSequencer 계정에 입금 중입니다...${NC}"
    ./computing-provider sequencer add --from $sequencer_address $eth_amount

    # 서비스 시작
    echo "${GREEN}서비스를 시작합니다...${NC}"
    export FIL_PROOFS_PARAMETER_CACHE=$PARENT_PATH

    read -p "${YELLOW}시스템에 GPU가 있습니까? (y/n): ${NC}" has_gpu
    if [ "$has_gpu" == "y" ]; then
        read -p "${YELLOW}GPU 모델과 CUDA코어 수를 입력하세요 (예: GeForce RTX 4090:16384): ${NC}" gpu_info
        export RUST_GPU_TOOLS_CUSTOM_GPU="$gpu_info"
    else
        echo "${YELLOW}GPU 설정을 건너뜁니다.${NC}"
    fi

    nohup ./computing-provider ubi daemon >> cp.log 2>&1 &
}

# ZK 작업 목록 확인 함수
function view_zk_task_list() {
    echo "${GREEN}ZK 작업 목록을 확인 중입니다...${NC}"
    ./computing-provider ubi list --show-failed
}

# 노드 로그 조회 함수
function query_node_logs() {
    echo "${GREEN}노드 로그를 조회 중입니다...${NC}"
    cd ~/.swan/computing || exit
    tail -f ubi-ecp.log
}

# 노드 재시작 함수
function restart_node() {
    echo -e "${GREEN}config.toml 파일을 수정 중입니다...${NC}"

    # 설정 파일 디렉토리로 이동
    cd ~/.swan/computing || exit
    config_file="$HOME/.swan/computing/config.toml"

    # EnableSequencer를 true로 설정
    sed -i 's/^EnableSequencer = .*/EnableSequencer = true/' "$config_file"

    # AutoChainProof를 false로 설정
    sed -i 's/^AutoChainProof = .*/AutoChainProof = false/' "$config_file"

    echo -e "${GREEN}config.toml 파일 수정이 완료되었습니다.${NC}"

    # 계산 노드 명령 실행
    echo -e "${GREEN}지갑 주소를 입력하세요: ${NC}"
    read -r wallet_address
    echo -e "${GREEN}입금할 금액을 입력하세요: ${NC}"
    read -r amount

    echo -e "${GREEN}sequencer add 명령을 실행 중입니다...${NC}"
    ./computing-provider sequencer add --from "$wallet_address" "$amount"

    # 환경 변수를 설정하고 서비스를 다시 시작
    export FIL_PROOFS_PARAMETER_CACHE=$PARENT_PATH

    read -p "${YELLOW}시스템에 GPU가 있습니까? (y/n): ${NC}" has_gpu
    if [ "$has_gpu" == "y" ]; then
        read -p "${YELLOW}GPU 모델과 코어 수를 입력하세요 (예: GeForce RTX 4090:16384): ${NC}" gpu_info
        export RUST_GPU_TOOLS_CUSTOM_GPU="$gpu_info"
    else
        echo -e "${YELLOW}GPU가 감지되지 않았습니다. GPU 설정을 건너뜁니다.${NC}"
    fi

    echo -e "${GREEN}노드를 다시 시작합니다...${NC}"
    nohup ./computing-provider ubi daemon >> cp.log 2>&1 &

    echo -e "${BLUE}노드가 재시작되었습니다.${NC}"
}

# 현재 실행 중인 작업 목록 확인 함수
function view_running_tasks() {
    echo "${GREEN}현재 실행 중인 작업 목록을 확인 중입니다...${NC}"
    ./computing-provider task list -v
}

# 메인 메뉴 함수 실행
main_menu

echo -e "${YELLOW}대시보드를 확인해주세요: https://provider.swanchain.io/rankings/ecp ${NC}"
echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤 A+D로 스크린을 나가주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
