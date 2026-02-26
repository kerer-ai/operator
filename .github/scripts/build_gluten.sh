#!/bin/bash
set -euo pipefail  # 严格模式：命令失败/未定义变量立即退出
trap 'cleanup_on_exit' EXIT  # 脚本退出时执行清理操作

# ==============================================================================
# 【配置区】- 请根据实际场景修改以下配置，注释已标注每个配置的用途
# ==============================================================================
# 华为云SWR公开镜像地址（格式：swr.区域.myhuaweicloud.com/命名空间/镜像名:标签）
readonly SWR_PUBLIC_IMAGE="swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:arm64_003"
# 构建容器名称（建议包含项目标识，避免冲突）
readonly BUILD_CONTAINER_NAME="gluten-project-builder"
# 代码仓库地址（支持HTTP/SSH，如GitHub/Gitee/GitLab）
readonly CODE_REPOSITORY="https://gitcode.com/kerer-sk/Gluten.git"
# 代码仓库分支（可根据需要修改，如main/dev/v1.0.0）
readonly CODE_BRANCH="master"
# 容器内代码存放目录（绝对路径，建议/opt/项目名）
readonly CONTAINER_CODE_DIR="/opt/gluten"
# 容器内构建脚本路径（相对于CONTAINER_CODE_DIR）
readonly CONTAINER_BUILD_SCRIPT=".build/scripts/gluten_compile.sh"
# 本地构建产物挂载目录（同步容器内构建结果到本地，避免产物丢失）
readonly LOCAL_BUILD_OUTPUT_DIR="./build-output"
# 日志级别（INFO/ERROR，仅控制输出粒度，不影响核心逻辑）
readonly LOG_LEVEL="INFO"
# Maven仓库目录（可选：如果构建脚本依赖Maven构建，建议挂载本地仓库加速构建，避免每次都下载依赖）
readonly LOCAL_BUILD_MAVEN_REPO_DIR="./maven-docker-cache"

# ==============================================================================
# 【工具函数区】- 通用工具函数，职责单一，可复用
# ==============================================================================



# 函数：检查Docker依赖（是否安装+是否运行）
check_docker_dependency() {
    echo "开始检查Docker环境依赖..."

    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        echo "Docker未安装，请先安装Docker后再执行脚本！"
        exit 1
    fi

    # 检查Docker服务是否运行
    if ! docker info &> /dev/null; then
        echo "Docker服务未运行，请执行 'systemctl start docker' 启动服务后再试！"
        exit 1
    fi

    # 检查是否支持多架构（qemu）
    if ! docker run --rm --platform linux/arm64 alpine:latest uname -m &> /dev/null; then
        echo "检测到需要安装 qemu 以支持 arm64 架构"
        # 尝试安装 qemu
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y qemu-user-static
        elif command -v yum &> /dev/null; then
            sudo yum install -y qemu-user-static
        else
            echo "无法自动安装 qemu，请手动安装以支持 arm64 架构"
        fi
    fi

    echo "Docker环境依赖检查通过"
}

# 函数：检查容器是否存在
# 参数1：容器名称
# 返回值：0（存在）/1（不存在）
is_container_exists() {
    local container_name="$1"
    docker ps -a --filter "name=^/${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"
    return $?
}

# 函数：清理指定容器（停止+删除）
# 参数1：容器名称
cleanup_container() {
    local container_name="$1"

    if is_container_exists "$container_name"; then
        echo "清理旧容器 [$container_name]..."

        # 停止容器（忽略停止失败，比如容器已停止）
        if docker stop "$container_name" &> /dev/null; then
            echo "容器 [$container_name] 已停止"
        fi

        # 删除容器（忽略删除失败）
        if docker rm "$container_name" &> /dev/null; then
            echo "容器 [$container_name] 已删除"
        fi
    fi
}

# 函数：创建本地目录（确保目录存在，避免挂载失败）
# 参数1：目录路径
create_local_directory() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        echo "创建本地目录 [$dir_path]..."
        mkdir -p "$dir_path"
    fi
}

# ==============================================================================
# 【核心流程函数区】- 按构建流程拆分，每个函数仅负责一个核心步骤
# ==============================================================================

# 函数：拉取华为云SWR公开镜像
pull_swr_public_image() {
    echo "开始拉取SWR公开镜像：$SWR_PUBLIC_IMAGE"

    if docker pull "$SWR_PUBLIC_IMAGE"; then
        echo "SWR镜像拉取成功"
    else
        echo "SWR镜像拉取失败！请检查：1.镜像地址是否正确 2.网络是否能访问华为云SWR"
        exit 1
    fi
}

# 函数：启动构建容器（挂载本地目录，保持后台运行）
start_build_container() {
    echo "启动构建容器 [$BUILD_CONTAINER_NAME]..."

    # 创建本地产物目录
    create_local_directory "$LOCAL_BUILD_OUTPUT_DIR"
    # 创建本地Maven仓库目录
    create_local_directory "$LOCAL_BUILD_MAVEN_REPO_DIR"
    
    docker run -d \
        --name "$BUILD_CONTAINER_NAME" \
        --platform linux/arm64 \
        --user root \
        --entrypoint /bin/sh \
        -v "$LOCAL_BUILD_OUTPUT_DIR:/opt/build-output" \
        -v "$LOCAL_BUILD_MAVEN_REPO_DIR:/root/.m2" \
        --workdir "/opt" \
        "$SWR_PUBLIC_IMAGE" \
        -c "tail -f /dev/null" 

    # 验证容器是否启动成功
    if is_container_exists "$BUILD_CONTAINER_NAME" && docker ps --filter "name=^/${BUILD_CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "^${BUILD_CONTAINER_NAME}$"; then
        echo "构建容器 [$BUILD_CONTAINER_NAME] 启动成功"
    else
        echo "构建容器启动失败！请检查镜像是否可正常运行"
        exit 1
    fi
}

# 函数：拉取代码到容器内（指定分支）
pull_code_to_container() {
    log "INFO" "拉取代码 [$CODE_REPOSITORY] 到容器，分支：$CODE_BRANCH..."

    # 容器内执行git操作：确保目录为空后克隆，已有仓库则拉取
    docker exec -u root "$BUILD_CONTAINER_NAME" bash -c "\
        set -euo pipefail; \
        rm -rf $CONTAINER_CODE_DIR; \
        git clone $CODE_REPOSITORY $CONTAINER_CODE_DIR; \
        cd $CONTAINER_CODE_DIR; \
        git checkout $CODE_BRANCH; \
    "

    log "INFO" "代码拉取完成，存放路径：$CONTAINER_CODE_DIR"
}

# 函数：执行容器内的构建脚本
execute_build_script() {
    local full_build_script_path="$CONTAINER_CODE_DIR/$CONTAINER_BUILD_SCRIPT"
    echo "执行构建脚本：$full_build_script_path"

    # 容器内执行构建：添加执行权限 + 运行脚本
    docker exec "$BUILD_CONTAINER_NAME" bash -c "\
        set -euo pipefail; \
        if [[ ! -f $full_build_script_path ]]; then
            echo '构建脚本不存在！路径：$full_build_script_path';
            exit 1;
        fi; \
        chmod +x $full_build_script_path; \
        $full_build_script_path package;
    "

    echo "构建脚本执行完成！构建产物已同步到本地：$LOCAL_BUILD_OUTPUT_DIR"
}

# ==============================================================================
# 【脚本生命周期函数】- 入口/退出清理
# ==============================================================================

# 函数：脚本退出时的清理操作（可选：如需保留容器可注释此函数内的清理逻辑）
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "脚本执行失败，退出码：$exit_code"
        # 失败时可选择保留容器用于排查问题，注释下面的行即可
        cleanup_container "$BUILD_CONTAINER_NAME"
    else
        echo "脚本执行成功！如需清理容器，可执行：docker stop $BUILD_CONTAINER_NAME && docker rm $BUILD_CONTAINER_NAME"
    fi
}

# 函数：脚本主入口（按流程串联所有步骤）
main() {
    echo "==================== 开源项目一键构建脚本启动 ===================="

    # 步骤1：检查依赖
    check_docker_dependency

    # 步骤2：清理旧容器（避免冲突）
    cleanup_container "$BUILD_CONTAINER_NAME"

    # 步骤3：拉取SWR公开镜像
    pull_swr_public_image

    # 步骤4：启动构建容器
    start_build_container

    # 步骤5：拉取代码到容器
    pull_code_to_container

    # 步骤6：执行构建脚本
    execute_build_script

    echo "==================== 开源项目一键构建脚本完成 ===================="
}

# 执行主函数（脚本入口）
main