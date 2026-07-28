%% experiment_04_detectability_bound.m  实验 04 — 故障可检测性边界验证
%  目标：验证论文公式 (31)(32) 的可检测性边界——故障幅值达到边界时
%        能以概率 1 被检出。分别注入传感器故障 f_y 与执行器故障 f_u，
%        幅值从 0 逐步增大，每个幅值做 N_mc 次蒙特卡洛仿真，统计检出率。
%
%  核心验证逻辑：
%    1. 离线设计：完成 Model 1→2→组装→LMI→拆分的完整链路
%    2. 阈值计算：J_{th,ω} = chi2inv(0.99, dim_ω)  各中心独立门限
%    3. 蒙特卡洛：对每个故障幅值/类型，重复 N_mc 次
%       - 不同噪声种子生成正常工况仿真数据
%       - 注入故障（k_fault 时刻起）
%       - 计算各中心残差与 J_{T^2,ω}(k)（公式 27）
%       - 检查 k ≥ k_fault 后是否有 J_{T^2,ω} 超过 J_{th,ω}
%    4. 统计：故障幅值—检出率曲线，检出延迟分布
%    5. 理论边界：基于 DC 增益推导近似理论界，与经验边界对比
%
%  验收标准：
%    运行后报告不同故障幅值下的实际检出率，与理论边界对比。
%
%  依赖：
%    src/lib/     — model_1_to_model_2, assemble_global_model, solve_luenberger_lmi,
%                   split_matrices_and_cov, compute_online_residuals, inject_fault
%    src/scripts/ — create_model_1
%    utils/       — create_controlled_system, calculate_lqr, run_visualization

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  1. 离线设计：完整链路（同实验 02）
% ============================================================
fprintf('========== 实验 04：故障可检测性边界验证 ==========\n\n');
fprintf('--- 1. 离线设计 ---\n');

% 1a. 加载 Model 1
create_model_1;

% 1b. Model 1 → Model 2（公式 7-10）
[A_bar, B_bar, C_bar, D_bar] = ...
    model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

% 1c. 全局矩阵组装（公式 11-14）
[A_g, B_g, C_g, D_g] = assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

% 1d. LMI/DARE 求解全局观测器矩阵
[A_z, L] = solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

% 1e. 计算中心划分
n_omega = 2;
indices_omega = {[1, 3], [2, 4]};

% 1f. 矩阵拆分与协方差计算（公式 19, 25-26）
[A_z_omega, L_omega, Sigma_r_omega, ~] = ...
    split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

% 1g. 额外计算：状态估计误差协方差 Σ_{e,s}（用于 r_s 的 T² 统计量）
%     与实验 02 相同：r_s 观测器不受测量噪声驱动
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
Sigma_e_s   = dlyap(A_z, Sigma_w_full);       % r_s 使用的误差协方差

fprintf('  离线设计完成：n_omega=%d, N_x=%d, N_y=%d\n', n_omega, size(A_g,1), size(C_g,1));

%% ============================================================
%  2. 被控系统与 LQR 控制器
% ============================================================
fprintf('\n--- 2. 被控系统与控制器 ---\n');

[A_g_sys, B_g_sys, C_g_sys, D_g_sys, ~, ~, ~] = create_controlled_system();
K = calculate_lqr(A_g_sys, B_g_sys);

N_x = size(A_g_sys, 1);     % 全局状态维度 = 4
N_u = size(B_g_sys, 2);     % 全局输入维度 = 2
N_y = size(C_g_sys, 1);     % 全局输出维度 = 2

fprintf('  A_g_sys=%d×%d, B_g_sys=%d×%d, LQR K=%d×%d\n', ...
    N_x, N_x, N_x, N_u, size(K,1), size(K,2));

% 验证闭环稳定性
eig_cl = abs(eig(A_g_sys - B_g_sys * K));
if all(eig_cl < 1)
    stability_str = '✓（稳定）';
else
    stability_str = '✗（不稳定！）';
end
fprintf('  闭环 max|λ| = %.6f  %s\n', max(eig_cl), stability_str);

%% ============================================================
%  3. 阈值计算：J_{th,ω} = chi2inv(0.99, dim_ω)
% ============================================================
fprintf('\n--- 3. 门限计算 ---\n');

% 输出残差 r_y 的 T² 门限（各中心独立）
conf_level = 0.99;
J_th_ry = zeros(1, n_omega);
dim_ry = zeros(1, n_omega);

for omega = 1:n_omega
    dim_ry(omega) = size(Sigma_r_omega{omega}, 1);
    if dim_ry(omega) > 0
        J_th_ry(omega) = chi2inv(conf_level, dim_ry(omega));
    else
        J_th_ry(omega) = NaN;
    end
    fprintf('  中心 %d: r_y 维度=%d,  J_th^y = %.4f\n', ...
        omega, dim_ry(omega), J_th_ry(omega));
end

% ---- 构建局域索引（用于 r_s 相关维度和协方差）----
cum_nx_global = [0, cumsum(n_x)];
state_rows_global = cell(1, n_s);
for i = 1:n_s
    state_rows_global{i} = (cum_nx_global(i)+1) : cum_nx_global(i+1);
end

% r_s 协方差与门限
rows_x_omega   = cell(1, n_omega);
Cs_omega       = cell(1, n_omega);
Sigma_rs_omega = cell(1, n_omega);
J_th_rs        = zeros(1, n_omega);
dim_rs         = zeros(1, n_omega);

for omega = 1:n_omega
    idx = indices_omega{omega};

    % 局域状态行索引
    rx = [];
    for s_local = idx
        rx = [rx, state_rows_global{s_local}]; %#ok<AGROW>
    end
    rows_x_omega{omega} = rx;

    % C_{s,ω} = blkdiag(C_s{idx})
    Cs_blocks = {};
    for s_local = idx
        if ~isempty(C_s{s_local})
            Cs_blocks{end+1} = C_s{s_local}; %#ok<AGROW>
        end
    end
    if ~isempty(Cs_blocks)
        Cs_omega{omega} = blkdiag(Cs_blocks{:});
    else
        Cs_omega{omega} = [];
    end

    % r_s 理论协方差：Σ_{r_s,ω} = C_{s,ω} · Σ_{e,s,ω} · C_{s,ω}'
    Sigma_e_s_omega = Sigma_e_s(rx, rx);
    if ~isempty(Cs_omega{omega})
        Sigma_rs_omega{omega} = Cs_omega{omega} * Sigma_e_s_omega * Cs_omega{omega}';
    else
        Sigma_rs_omega{omega} = [];
    end

    dim_rs(omega) = size(Sigma_rs_omega{omega}, 1);
    if dim_rs(omega) > 0
        J_th_rs(omega) = chi2inv(conf_level, dim_rs(omega));
    else
        J_th_rs(omega) = NaN;
    end
    fprintf('  中心 %d: r_s 维度=%d,  J_th^s = %.4f\n', ...
        omega, dim_rs(omega), J_th_rs(omega));
end

%% ============================================================
%  4. 蒙特卡洛仿真参数设置
% ============================================================
fprintf('\n--- 4. 蒙特卡洛仿真参数 ---\n');

T_sim  = 500;           % 每次运行的仿真步长
k_fault = 200;          % 故障注入时刻（步数）

% 故障幅值扫描范围
n_mag = 15;
mag_sensor   = linspace(0, 0.5, n_mag);    % 传感器故障幅值
mag_actuator = linspace(0, 2.0, n_mag);    % 执行器故障幅值

N_mc = 30;              % 每个幅值的蒙特卡洛重复次数

% 故障注入目标
fault_subsys_sensor = 1;   % 传感器故障注入子系统 1（中心 1 管辖，有传感器）
                            % 注意：子系统 2 也有传感器，选 1 作为代表

fprintf('  T_sim=%d, k_fault=%d, N_mc=%d, n_mag=%d\n', T_sim, k_fault, N_mc, n_mag);
fprintf('  传感器故障幅值范围: [%.4f, %.4f], 注入子系统 %d\n', ...
    mag_sensor(1), mag_sensor(end), fault_subsys_sensor);
fprintf('  执行器故障幅值范围: [%.4f, %.4f]\n', ...
    mag_actuator(1), mag_actuator(end));

% 预分配检测结果存储
detect_rate_sensor   = zeros(1, n_mag);   % 传感器故障检出率
detect_rate_actuator = zeros(1, n_mag);   % 执行器故障检出率
detect_delay_sensor  = cell(1, n_mag);    % 传感器故障检出延迟（各 MC run）
detect_delay_actuator = cell(1, n_mag);   % 执行器故障检出延迟

% 噪声协方差矩阵（用于直接生成噪声）
Sigma_w_mat = Sigma_w_full;
Sigma_v_mat = Sigma_v_full;
chol_w = chol(Sigma_w_mat, 'lower');
chol_v = chol(Sigma_v_mat, 'lower');

%% ============================================================
%  5. 蒙特卡洛仿真 — 传感器故障
% ============================================================
fprintf('\n===== 5. 蒙特卡洛仿真 — 传感器故障 =====\n\n');

for mag_idx = 1:n_mag
    mag = mag_sensor(mag_idx);
    detected_count = 0;
    delays = zeros(1, N_mc);

    fprintf('  传感器故障 mag=%.4f (%d/%d): 运行 MC...', mag, mag_idx, n_mag);

    for mc = 1:N_mc
        % ---- 5a. 设置独立噪声种子 ----
        rng(mc * 1000 + mag_idx * 10);

        % ---- 5b. 生成噪声序列 ----
        %  直接使用 chol * randn 以提高性能（等效于 create_noise_v2 的高斯噪声）
        w_seq = chol_w * randn(N_x, T_sim);    % 4 × T_sim
        v_seq = chol_v * randn(N_y, T_sim);    % 2 × T_sim

        % ---- 5c. LQR 闭环仿真（正常工况）----
        x_seq = zeros(N_x, T_sim);
        u_seq = zeros(N_u, T_sim);
        y_seq = zeros(N_y, T_sim);
        s_cell = cell(1, n_s);
        cum_nx = [0, cumsum(n_x)];
        for i = 1:n_s
            s_cell{i} = zeros(n_x(i), T_sim);
        end

        x_k = zeros(N_x, 1);
        for k = 1:T_sim
            u_k = -K * x_k;
            u_seq(:, k) = u_k;
            y_seq(:, k) = C_g_sys * x_k + v_seq(:, k);

            for i = 1:n_s
                idx_i = (cum_nx(i)+1) : cum_nx(i+1);
                s_cell{i}(:, k) = C_s{i} * x_k(idx_i) + D_s{i} * u_k;
            end

            x_seq(:, k) = x_k;
            if k < T_sim
                x_k = A_g_sys * x_k + B_g_sys * u_k + w_seq(:, k);
            end
        end

        % ---- 5d. 注入传感器故障 ----
        [y_faulty, u_faulty] = inject_fault(y_seq, u_seq, ...
            'sensor', fault_subsys_sensor, mag, k_fault);

        % ---- 5e. 计算残差 ----
        [r_y, r_s] = compute_online_residuals(...
            u_faulty, y_faulty, s_cell, ...
            A_z_omega, L_omega, ...
            B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
            indices_omega, n_x, n_y, n_s);

        % ---- 5f. 计算 J_{T^2} 并检查检出 ----
        detected = false;
        det_step = T_sim;  % 初始化检出步长（用于最小检出步长跟踪）

        for k_step = k_fault:T_sim
            if detected, break; end

            for omega = 1:n_omega
                % 输出残差 T² 统计量
                if dim_ry(omega) > 0 && ~isempty(r_y{omega})
                    r_y_k = r_y{omega}(:, k_step);
                    J_ry = r_y_k' * (Sigma_r_omega{omega} \ r_y_k);
                    if J_ry > J_th_ry(omega)
                        detected = true;
                        det_step = k_step;
                        break;
                    end
                end

                % 发送信息残差 T² 统计量
                if dim_rs(omega) > 0 && ~isempty(r_s{omega}) ...
                        && ~isempty(Sigma_rs_omega{omega})
                    r_s_k = r_s{omega}(:, k_step);
                    J_rs = r_s_k' * (Sigma_rs_omega{omega} \ r_s_k);
                    if J_rs > J_th_rs(omega)
                        detected = true;
                        det_step = k_step;
                        break;
                    end
                end
            end
        end

        if detected
            detected_count = detected_count + 1;
            delays(mc) = det_step - k_fault;
        else
            delays(mc) = NaN;
        end
    end

    detect_rate_sensor(mag_idx) = detected_count / N_mc;
    detect_delay_sensor{mag_idx} = delays;
    valid_delays = delays(~isnan(delays));

    if isempty(valid_delays)
        fprintf(' 检出率 = %d/%d = %.2f,  检出延迟 = N/A\n', ...
            detected_count, N_mc, detect_rate_sensor(mag_idx));
    else
        fprintf(' 检出率 = %d/%d = %.2f,  检出延迟均值 = %.1f,  中位 = %.1f\n', ...
            detected_count, N_mc, detect_rate_sensor(mag_idx), ...
            mean(valid_delays), median(valid_delays));
    end
end

%% ============================================================
%  6. 蒙特卡洛仿真 — 执行器故障
% ============================================================
fprintf('\n===== 6. 蒙特卡洛仿真 — 执行器故障 =====\n\n');

for mag_idx = 1:n_mag
    mag = mag_actuator(mag_idx);
    detected_count = 0;
    delays = zeros(1, N_mc);

    fprintf('  执行器故障 mag=%.4f (%d/%d): 运行 MC...', mag, mag_idx, n_mag);

    for mc = 1:N_mc
        % ---- 6a. 设置独立噪声种子 ----
        rng(mc * 1000 + mag_idx * 10 + 50000);  % 偏移以区别于传感器故障种子

        % ---- 6b. 生成噪声序列 ----
        w_seq = chol_w * randn(N_x, T_sim);
        v_seq = chol_v * randn(N_y, T_sim);

        % ---- 6c. LQR 闭环仿真（正常工况）----
        x_seq = zeros(N_x, T_sim);
        u_seq = zeros(N_u, T_sim);
        y_seq = zeros(N_y, T_sim);
        s_cell = cell(1, n_s);
        cum_nx = [0, cumsum(n_x)];
        for i = 1:n_s
            s_cell{i} = zeros(n_x(i), T_sim);
        end

        x_k = zeros(N_x, 1);
        for k = 1:T_sim
            u_k = -K * x_k;
            u_seq(:, k) = u_k;
            y_seq(:, k) = C_g_sys * x_k + v_seq(:, k);

            for i = 1:n_s
                idx_i = (cum_nx(i)+1) : cum_nx(i+1);
                s_cell{i}(:, k) = C_s{i} * x_k(idx_i) + D_s{i} * u_k;
            end

            x_seq(:, k) = x_k;
            if k < T_sim
                x_k = A_g_sys * x_k + B_g_sys * u_k + w_seq(:, k);
            end
        end

        % ---- 6d. 注入执行器故障 ----
        [y_faulty, u_faulty] = inject_fault(y_seq, u_seq, ...
            'actuator', 1, mag, k_fault);  % fault_subsys 在执行器故障下不影响行为

        % ---- 6e. 计算残差 ----
        [r_y, r_s] = compute_online_residuals(...
            u_faulty, y_faulty, s_cell, ...
            A_z_omega, L_omega, ...
            B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
            indices_omega, n_x, n_y, n_s);

        % ---- 6f. 计算 J_{T^2} 并检查检出 ----
        detected = false;
        det_step = T_sim;

        for k_step = k_fault:T_sim
            if detected, break; end

            for omega = 1:n_omega
                % 输出残差 T² 统计量
                if dim_ry(omega) > 0 && ~isempty(r_y{omega})
                    r_y_k = r_y{omega}(:, k_step);
                    J_ry = r_y_k' * (Sigma_r_omega{omega} \ r_y_k);
                    if J_ry > J_th_ry(omega)
                        detected = true;
                        det_step = k_step;
                        break;
                    end
                end

                % 发送信息残差 T² 统计量
                if dim_rs(omega) > 0 && ~isempty(r_s{omega}) ...
                        && ~isempty(Sigma_rs_omega{omega})
                    r_s_k = r_s{omega}(:, k_step);
                    J_rs = r_s_k' * (Sigma_rs_omega{omega} \ r_s_k);
                    if J_rs > J_th_rs(omega)
                        detected = true;
                        det_step = k_step;
                        break;
                    end
                end
            end
        end

        if detected
            detected_count = detected_count + 1;
            delays(mc) = det_step - k_fault;
        else
            delays(mc) = NaN;
        end
    end

    detect_rate_actuator(mag_idx) = detected_count / N_mc;
    detect_delay_actuator{mag_idx} = delays;
    valid_delays = delays(~isnan(delays));

    if isempty(valid_delays)
        fprintf(' 检出率 = %d/%d = %.2f,  检出延迟 = N/A\n', ...
            detected_count, N_mc, detect_rate_actuator(mag_idx));
    else
        fprintf(' 检出率 = %d/%d = %.2f,  检出延迟均值 = %.1f,  中位 = %.1f\n', ...
            detected_count, N_mc, detect_rate_actuator(mag_idx), ...
            mean(valid_delays), median(valid_delays));
    end
end

%% ============================================================
%  7. 经验边界提取（检出率首次达到 1.0 的幅值）
% ============================================================
fprintf('\n--- 7. 经验边界提取 ---\n');

% 传感器故障经验边界
idx_emp_sensor = find(detect_rate_sensor >= 1.0, 1, 'first');
if ~isempty(idx_emp_sensor)
    mag_emp_bound_sensor = mag_sensor(idx_emp_sensor);
    fprintf('  传感器故障经验边界: %.6f（幅值索引 %d，检出率=%.2f）\n', ...
        mag_emp_bound_sensor, idx_emp_sensor, detect_rate_sensor(idx_emp_sensor));
else
    mag_emp_bound_sensor = mag_sensor(end);
    fprintf('  传感器故障经验边界: 未达到 1.0，最大幅值 %.6f 时检出率=%.2f\n', ...
        mag_emp_bound_sensor, detect_rate_sensor(end));
end

% 执行器故障经验边界
idx_emp_actuator = find(detect_rate_actuator >= 1.0, 1, 'first');
if ~isempty(idx_emp_actuator)
    mag_emp_bound_actuator = mag_actuator(idx_emp_actuator);
    fprintf('  执行器故障经验边界: %.6f（幅值索引 %d，检出率=%.2f）\n', ...
        mag_emp_bound_actuator, idx_emp_actuator, detect_rate_actuator(idx_emp_actuator));
else
    mag_emp_bound_actuator = mag_actuator(end);
    fprintf('  执行器故障经验边界: 未达到 1.0，最大幅值 %.6f 时检出率=%.2f\n', ...
        mag_emp_bound_actuator, detect_rate_actuator(end));
end

%% ============================================================
%  8. 理论边界计算（基于 DC 增益近似）
% ============================================================
fprintf('\n--- 8. 理论边界计算（DC 增益近似）---\n');
fprintf('  注：以下为基于局部模型的 DC 增益近似，精确理论界需进一步推导。\n\n');

% ---- 8a. 传感器故障理论边界 ----
%   公式 (31): |f_y| > √(2·J_{th,ω}) / ‖Σ_{r,ω}^{-1/2} · G_{z,ω} · Ψ_y‖
%
%   对于恒定故障，取 DC 增益 G_f(1) = I - C_g·(I-A_z)^{-1}·L
%   局域化到中心 ω：G_f,ω(1) = I - C_{g,ω}·(I-A_{z,ω})^{-1}·L_ω
%
%   传感器故障方向：Ψ_y 指向故障注入位置
%   对于注入子系统 1，在全局输出子空间：Ψ_y = e_{y1}（第一标准基向量）

% 构建全局 C_g 和 L 的局域版本（与 compute_online_residuals 一致）
[~, C_g_omega_local, ~, ~, ~, ~, ~, ~] = build_local_matrices(...
    A_z_omega, L_omega, B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
    indices_omega, n_x, n_y, n_s);

% 传感器故障 DC 增益（对中心 1，因为它管辖有传感器的子系统 1）
omega_sensor = find(cellfun(@(idx) ismember(fault_subsys_sensor, idx), indices_omega));
fprintf('  传感器故障影响中心: %d（管辖子系统 %s）\n', ...
    omega_sensor, mat2str(indices_omega{omega_sensor}));

A_z_loc = A_z_omega{omega_sensor};
C_g_loc = C_g_omega_local{omega_sensor};
L_loc   = L_omega{omega_sensor};
Sigma_r_loc = Sigma_r_omega{omega_sensor};

if ~isempty(C_g_loc) && ~isempty(L_loc) && ~isempty(Sigma_r_loc)
    % DC 增益矩阵: G_f = I - C_g_loc * (I - A_z_loc)^{-1} * L_loc
    I_az = eye(size(A_z_loc));
    G_f_dc = eye(size(C_g_loc, 1)) - C_g_loc * (I_az - A_z_loc) \ L_loc;

    % 故障方向：传感器故障影响 y_1（中心 1 的输出第一个分量）
    % 由于 y_1 是中心 1 的唯一天量输出，fault_subsys=1 输出在全局 y 的第 1 行
    % 局域 y 的索引取决于 output_rows 构建
    Psi_y = zeros(size(C_g_loc, 1), 1);
    Psi_y(1) = 1;  % 假设故障注入在局域输出的第一个分量

    % Σ_r^{-1/2}
    Sigma_r_inv_sqrt = Sigma_r_loc^(-1/2);  % 对称平方根逆

    % 有效增益范数
    G_eff = Sigma_r_inv_sqrt * G_f_dc * Psi_y;
    norm_G_eff = norm(G_eff);

    if norm_G_eff > 1e-12
        mag_theory_bound_sensor = sqrt(2 * J_th_ry(omega_sensor)) / norm_G_eff;
        fprintf('  传感器故障 DC 增益范数 ‖Σ_r^{-1/2}·G_f(I)·Ψ_y‖ = %.6f\n', norm_G_eff);
        fprintf('  传感器故障理论边界（公式 31 近似）: |f_y| > %.6f\n', ...
            mag_theory_bound_sensor);
    else
        mag_theory_bound_sensor = inf;
        fprintf('  传感器故障 DC 增益接近于零，理论边界 → ∞（可能数值问题）\n');
    end
else
    mag_theory_bound_sensor = inf;
    fprintf('  传感器故障理论边界: 无法计算（局域矩阵为空）\n');
end

% ---- 8b. 执行器故障理论边界 ----
%   公式 (32): |f_u| > √(2·J_{th,ω}) / ‖Σ_{r,ω}^{-1/2} · D_{z,ω} · Ψ_u‖
%
%   执行器故障路径：u → 残差 r 的 DC 增益
%   G_u(I) = -(C_g·(I-A_z)^{-1}·B_z + D_g)
%   局域化：G_u,ω(I) = -(C_{g,ω}·(I-A_{z,ω})^{-1}·B_{z,ω} + D_{g,ω})
%
%   执行器故障方向 Ψ_u：inject_fault 对 u 的所有分量叠加相同幅值
%   → Ψ_u = [1; 1]（归一化前）

% 选择输出维度最大的中心（对执行器故障更敏感）
[~, omega_best_actuator] = max(dim_ry);

fprintf('\n  执行器故障分析中心: %d（管辖子系统 %s, r_y 维度=%d）\n', ...
    omega_best_actuator, mat2str(indices_omega{omega_best_actuator}), ...
    dim_ry(omega_best_actuator));

A_z_loc_u = A_z_omega{omega_best_actuator};
C_g_loc_u = C_g_omega_local{omega_best_actuator};
D_g_loc_u = D_g_sys;  % 需要局域化
L_loc_u   = L_omega{omega_best_actuator};
Sigma_r_loc_u = Sigma_r_omega{omega_best_actuator};

if ~isempty(C_g_loc_u) && ~isempty(L_loc_u) && ~isempty(Sigma_r_loc_u)
    % 局域 B_z = B_g_loc - L_loc * D_g_loc
    rows_x_u = rows_x_omega{omega_best_actuator};
    B_g_loc_u = B_g_sys(rows_x_u, :);

    % 局域输出行索引
    rows_y_u = [];
    cum_ny = [0, cumsum(n_y)];
    for s_local = indices_omega{omega_best_actuator}
        if n_y(s_local) > 0
            rows_y_u = [rows_y_u, (cum_ny(s_local)+1):cum_ny(s_local+1)]; %#ok<AGROW>
        end
    end
    D_g_loc_u = D_g_sys(rows_y_u, :);

    B_z_loc_u = B_g_loc_u - L_loc_u * D_g_loc_u;

    % DC 增益: G_u(I) = -(C_g_loc * (I - A_z_loc)^{-1} * B_z_loc + D_g_loc)
    I_az_u = eye(size(A_z_loc_u));
    G_u_dc = -(C_g_loc_u * (I_az_u - A_z_loc_u) \ B_z_loc_u + D_g_loc_u);

    % 执行器故障方向：Ψ_u = [1; 1]（两个泵同时受力）
    Psi_u = ones(N_u, 1);

    % Σ_r^{-1/2}
    Sigma_r_inv_sqrt_u = Sigma_r_loc_u^(-1/2);

    % 有效增益范数
    G_eff_u = Sigma_r_inv_sqrt_u * G_u_dc * Psi_u;
    norm_G_eff_u = norm(G_eff_u);

    if norm_G_eff_u > 1e-12
        mag_theory_bound_actuator = sqrt(2 * J_th_ry(omega_best_actuator)) / norm_G_eff_u;
        fprintf('  执行器故障 DC 增益范数 ‖Σ_r^{-1/2}·G_u(I)·Ψ_u‖ = %.6f\n', norm_G_eff_u);
        fprintf('  执行器故障理论边界（公式 32 近似）: |f_u| > %.6f\n', ...
            mag_theory_bound_actuator);
    else
        mag_theory_bound_actuator = inf;
        fprintf('  执行器故障 DC 增益接近于零，理论边界 → ∞（可能数值问题）\n');
    end
else
    mag_theory_bound_actuator = inf;
    fprintf('  执行器故障理论边界: 无法计算（局域矩阵为空）\n');
end

%% ============================================================
%  9. 可视化：故障幅值—检出率曲线
% ============================================================
fprintf('\n--- 9. 可视化 ---\n');

out_pic = '../../outputs/experiment_04_detectability_bound/figures/';
if ~exist(out_pic, 'dir'), mkdir(out_pic); end

% ---- 9a. 传感器故障检出率曲线 ----
figh_sensor = figure('Name', '实验04-传感器故障可检测性边界', 'NumberTitle', 'off');
hold on;

% 检出率曲线
plot(mag_sensor, detect_rate_sensor, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'b');

% 100% 参考线
yline(1.0, 'k--', 'LineWidth', 1.0);

% 经验边界
if ~isempty(idx_emp_sensor)
    xline(mag_emp_bound_sensor, 'r--', 'LineWidth', 1.2);
end

% 理论边界
if mag_theory_bound_sensor < mag_sensor(end) * 2
    xline(mag_theory_bound_sensor, 'g--', 'LineWidth', 1.2);
end

hold off;
xlabel('传感器故障幅值 |f_y|');
ylabel('检出率');
title(sprintf(['传感器故障可检测性边界（注入子系统 %d，N_{mc}=%d，' ...
    'k_{fault}=%d）'], fault_subsys_sensor, N_mc, k_fault));

legend_str = {'检出率', '100% 参考线'};
if ~isempty(idx_emp_sensor)
    legend_str{end+1} = sprintf('经验边界 %.4f', mag_emp_bound_sensor);
end
if mag_theory_bound_sensor < mag_sensor(end) * 2
    legend_str{end+1} = sprintf('理论边界 %.4f', mag_theory_bound_sensor);
end
legend(legend_str, 'Location', 'southeast');
grid on;
run_visualization(figh_sensor);

saveas(figh_sensor, [out_pic 'sensor_detectability.png']);
saveas(figh_sensor, [out_pic 'sensor_detectability.fig']);

% ---- 9b. 执行器故障检出率曲线 ----
figh_actuator = figure('Name', '实验04-执行器故障可检测性边界', 'NumberTitle', 'off');
hold on;

plot(mag_actuator, detect_rate_actuator, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'r');

yline(1.0, 'k--', 'LineWidth', 1.0);

if ~isempty(idx_emp_actuator)
    xline(mag_emp_bound_actuator, 'r--', 'LineWidth', 1.2);
end

if mag_theory_bound_actuator < mag_actuator(end) * 2
    xline(mag_theory_bound_actuator, 'g--', 'LineWidth', 1.2);
end

hold off;
xlabel('执行器故障幅值 |f_u|');
ylabel('检出率');
title(sprintf('执行器故障可检测性边界（N_{mc}=%d，k_{fault}=%d）', N_mc, k_fault));

legend_str_u = {'检出率', '100% 参考线'};
if ~isempty(idx_emp_actuator)
    legend_str_u{end+1} = sprintf('经验边界 %.4f', mag_emp_bound_actuator);
end
if mag_theory_bound_actuator < mag_actuator(end) * 2
    legend_str_u{end+1} = sprintf('理论边界 %.4f', mag_theory_bound_actuator);
end
legend(legend_str_u, 'Location', 'southeast');
grid on;
run_visualization(figh_actuator);

saveas(figh_actuator, [out_pic 'actuator_detectability.png']);
saveas(figh_actuator, [out_pic 'actuator_detectability.fig']);

% ---- 9c. 合并对比图 ----
figh_combined = figure('Name', '实验04-可检测性边界对比', 'NumberTitle', 'off');
hold on;

plot(mag_sensor, detect_rate_sensor, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'b', 'DisplayName', '传感器故障');
plot(mag_actuator, detect_rate_actuator, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'r', 'DisplayName', '执行器故障');

yline(1.0, 'k--', 'LineWidth', 1.0, 'DisplayName', '100% 检出');

hold off;
xlabel('故障幅值 |f|');
ylabel('检出率');
title(sprintf('故障可检测性边界对比（N_{mc}=%d，k_{fault}=%d）', N_mc, k_fault));
legend('Location', 'southeast');
grid on;
run_visualization(figh_combined);

saveas(figh_combined, [out_pic 'combined_detectability.png']);
saveas(figh_combined, [out_pic 'combined_detectability.fig']);

% ---- 9d. 传感器故障检出延迟随幅值变化（箱线图）----
figh_delay = figure('Name', '实验04-检出延迟分布', 'NumberTitle', 'off');
subplot(1, 2, 1);

% 提取有效幅值的检出延迟（仅绘制有检测的幅值）
valid_mag_idx_sensor = find(cellfun(@(d) any(~isnan(d)), detect_delay_sensor));
delay_data_sensor = {};
mag_labels_sensor = {};
for idx = valid_mag_idx_sensor
    d = detect_delay_sensor{idx};
    d_valid = d(~isnan(d));
    if ~isempty(d_valid)
        delay_data_sensor{end+1} = d_valid; %#ok<AGROW>
        mag_labels_sensor{end+1} = sprintf('%.3f', mag_sensor(idx)); %#ok<AGROW>
    end
end

if ~isempty(delay_data_sensor)
    boxplot_grouped(delay_data_sensor, mag_labels_sensor);
    xlabel('传感器故障幅值 |f_y|');
    ylabel('检出延迟（步数）');
    title('传感器故障检出延迟分布');
    grid on;
end

subplot(1, 2, 2);
valid_mag_idx_actuator = find(cellfun(@(d) any(~isnan(d)), detect_delay_actuator));
delay_data_actuator = {};
mag_labels_actuator = {};
for idx = valid_mag_idx_actuator
    d = detect_delay_actuator{idx};
    d_valid = d(~isnan(d));
    if ~isempty(d_valid)
        delay_data_actuator{end+1} = d_valid; %#ok<AGROW>
        mag_labels_actuator{end+1} = sprintf('%.2f', mag_actuator(idx)); %#ok<AGROW>
    end
end

if ~isempty(delay_data_actuator)
    boxplot_grouped(delay_data_actuator, mag_labels_actuator);
    xlabel('执行器故障幅值 |f_u|');
    ylabel('检出延迟（步数）');
    title('执行器故障检出延迟分布');
    grid on;
end

run_visualization(figh_delay);
saveas(figh_delay, [out_pic 'detection_delay_boxplot.png']);
saveas(figh_delay, [out_pic 'detection_delay_boxplot.fig']);

fprintf('  绘图完成。\n');

%% ============================================================
%  10. 汇总报告
% ============================================================
fprintf('\n===== 10. 汇总报告 =====\n\n');

fprintf('  ┌─────────────────────────────────────────────────────────────┐\n');
fprintf('  │              实验 04 — 故障可检测性边界                    │\n');
fprintf('  ├─────────────────────────────────────────────────────────────┤\n');

% ---- 传感器故障汇总表 ----
fprintf('  │  传感器故障（注入子系统 %d）                              │\n', fault_subsys_sensor);
fprintf('  │  %-8s %-12s %-12s %-15s\n', '幅值', '检出数', '检出率', '检出延迟均值');
fprintf('  │  %-8s %-12s %-12s %-15s\n', '----', '-----', '------', '------------');

for mag_idx = 1:n_mag
    d = detect_delay_sensor{mag_idx};
    d_valid = d(~isnan(d));
    if isempty(d_valid)
        delay_str = 'N/A';
    else
        delay_str = sprintf('%.1f 步', mean(d_valid));
    end
    fprintf('  │  %-8.4f %-12d %-12.2f %-15s\n', ...
        mag_sensor(mag_idx), ...
        round(detect_rate_sensor(mag_idx) * N_mc), ...
        detect_rate_sensor(mag_idx), delay_str);
end

fprintf('  ├─────────────────────────────────────────────────────────────┤\n');

% ---- 执行器故障汇总表 ----
fprintf('  │  执行器故障                                               │\n');
fprintf('  │  %-8s %-12s %-12s %-15s\n', '幅值', '检出数', '检出率', '检出延迟均值');
fprintf('  │  %-8s %-12s %-12s %-15s\n', '----', '-----', '------', '------------');

for mag_idx = 1:n_mag
    d = detect_delay_actuator{mag_idx};
    d_valid = d(~isnan(d));
    if isempty(d_valid)
        delay_str = 'N/A';
    else
        delay_str = sprintf('%.1f 步', mean(d_valid));
    end
    fprintf('  │  %-8.4f %-12d %-12.2f %-15s\n', ...
        mag_actuator(mag_idx), ...
        round(detect_rate_actuator(mag_idx) * N_mc), ...
        detect_rate_actuator(mag_idx), delay_str);
end

fprintf('  ├─────────────────────────────────────────────────────────────┤\n');
fprintf('  │  边界对比                                                 │\n');
fprintf('  │   传感器故障 — 经验边界: %.6f\n', mag_emp_bound_sensor);
if mag_theory_bound_sensor < inf
    fprintf('  │   传感器故障 — 理论边界: %.6f（DC 增益近似）\n', mag_theory_bound_sensor);
else
    fprintf('  │   传感器故障 — 理论边界: 无法计算\n');
end
fprintf('  │   执行器故障 — 经验边界: %.6f\n', mag_emp_bound_actuator);
if mag_theory_bound_actuator < inf
    fprintf('  │   执行器故障 — 理论边界: %.6f（DC 增益近似）\n', mag_theory_bound_actuator);
else
    fprintf('  │   执行器故障 — 理论边界: 无法计算\n');
end
fprintf('  └─────────────────────────────────────────────────────────────┘\n');

%% ============================================================
%  11. 验收判定
% ============================================================
fprintf('\n===== 11. 验收判定 =====\n\n');

sensor_bound_found = ~isempty(idx_emp_sensor);
actuator_bound_found = ~isempty(idx_emp_actuator);

if sensor_bound_found && actuator_bound_found
    fprintf('  实验 04 通过。\n');
    fprintf('    两种故障类型均在扫描范围内达到 100%% 检出率。\n');
    fprintf('    验证了可检测性边界的存在性——故障幅值达到阈值后能以概率 1 被检出。\n');
    fprintf('    传感器故障边界: |f_y| > %.6f\n', mag_emp_bound_sensor);
    fprintf('    执行器故障边界: |f_u| > %.6f\n', mag_emp_bound_actuator);
elseif sensor_bound_found
    fprintf('  实验 04 部分通过。\n');
    fprintf('    传感器故障：在幅值 %.6f 时达到 100%% 检出率。\n', mag_emp_bound_sensor);
    fprintf('    执行器故障：在扫描范围内未达到 100%% 检出率，需增大幅值范围。\n');
elseif actuator_bound_found
    fprintf('  实验 04 部分通过。\n');
    fprintf('    执行器故障：在幅值 %.6f 时达到 100%% 检出率。\n', mag_emp_bound_actuator);
    fprintf('    传感器故障：在扫描范围内未达到 100%% 检出率，需增大幅值范围。\n');
else
    fprintf('  实验 04 未完全通过。\n');
    fprintf('    两种故障类型在扫描范围内均未达到 100%% 检出率。\n');
    fprintf('    可能原因：\n');
    fprintf('      - 故障幅值范围不足，需增大 max_mag\n');
    fprintf('      - 仿真步长 T_sim=%d 不足，故障响应未充分发展\n', T_sim);
    fprintf('      - 蒙特卡洛次数 N_mc=%d 不足，统计不充分\n', N_mc);
    fprintf('      - 建议：增大 max_mag 和 T_sim 后重新运行\n');
end

%% ============================================================
%  12. 原理说明
% ============================================================
fprintf('\n--- 12. 原理说明 ---\n');
fprintf(['  故障可检测性基于 T² 统计量（公式 27）：\n' ...
        '    J_{T^2,ω}(k) = r_{ω,k}^T · Σ_{r,ω}^{-1} · r_{ω,k}\n\n' ...
        '  在无故障零假设下（H₀：f=0）：\n' ...
        '    J_{T^2,ω} ~ χ²(dim_ω)\n' ...
        '    门限 J_{th,ω} = χ²_{1-α}(dim_ω) 保证误报率 ≤ α\n\n' ...
        '  故障使残差均值偏移：r_k = r_k^0 + g_f · f\n' ...
        '  当故障幅值足够大时，偏移量使 J_{T^2} 以概率 1 超越门限。\n' ...
        '  可检测性边界（公式 31-32）给出了最小可检测故障幅值。\n\n' ...
        '  本实验通过 MC 仿真验证：\n' ...
        '    - 小故障幅值：检出率 < 1（偶尔漏检，受噪声掩蔽）\n' ...
        '    - 大故障幅值：检出率 = 1（总能检出，超越噪声波动）\n' ...
        '    - 边界附近：检出率从 0 急剧跳变到 1\n']);

%% ============================================================
%  13. 产出保存
% ============================================================
out_data = '../../outputs/experiment_04_detectability_bound/data/';
if ~exist(out_data, 'dir'), mkdir(out_data); end

save([out_data 'results.mat'], ...
    'mag_sensor', 'mag_actuator', ...
    'detect_rate_sensor', 'detect_rate_actuator', ...
    'detect_delay_sensor', 'detect_delay_actuator', ...
    'mag_emp_bound_sensor', 'mag_emp_bound_actuator', ...
    'mag_theory_bound_sensor', 'mag_theory_bound_actuator', ...
    'N_mc', 'T_sim', 'k_fault', 'n_mag', ...
    'J_th_ry', 'J_th_rs', 'dim_ry', 'dim_rs', ...
    'Sigma_r_omega', 'Sigma_rs_omega', ...
    'A_z_omega', 'L_omega', ...
    'indices_omega', 'n_omega', ...
    'fault_subsys_sensor');

fprintf('\n  产出已保存到 outputs/experiment_04_detectability_bound/\n');

fprintf('\n========== 实验 04 结束 ==========\n');

%% ============================================================
%  局部辅助函数
% ============================================================

function [B_z_omega, C_g_omega, D_g_omega, C_s_omega, D_s_omega, ...
          L_s_omega, state_idx_omega, output_idx_omega] = ...
    build_local_matrices(A_z_omega, L_omega, B_g, C_g, D_g, C_s, D_s, ...
                         indices_omega, n_x, n_y, n_s)
% build_local_matrices  构建各计算中心的局域矩阵（与 compute_online_residuals 内部逻辑一致）
%   供理论边界计算使用，避免重复 compute_online_residuals 的复杂索引逻辑。

n_omega = length(indices_omega);

% 状态索引映射
cum_n_x = [0, cumsum(n_x)];
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% 输出索引映射
cum_n_y = [0, cumsum(n_y)];
output_rows = cell(1, n_s);
for i = 1:n_s
    if n_y(i) > 0
        output_rows{i} = (cum_n_y(i) + 1) : cum_n_y(i + 1);
    else
        output_rows{i} = [];
    end
end

B_z_omega  = cell(1, n_omega);
C_g_omega  = cell(1, n_omega);
D_g_omega  = cell(1, n_omega);
C_s_omega  = cell(1, n_omega);
D_s_omega  = cell(1, n_omega);
L_s_omega  = cell(1, n_omega);
state_idx_omega = cell(1, n_omega);
output_idx_omega = cell(1, n_omega);

for omega = 1:n_omega
    idx = indices_omega{omega};

    % 状态行索引
    rows_x = [];
    for s = idx
        rows_x = [rows_x, state_rows{s}]; %#ok<AGROW>
    end
    state_idx_omega{omega} = rows_x;

    % 输出行索引
    rows_y = [];
    for s = idx
        if ~isempty(output_rows{s})
            rows_y = [rows_y, output_rows{s}]; %#ok<AGROW>
        end
    end
    output_idx_omega{omega} = rows_y;

    % B_{z,ω} = B_{g,ω} - L_ω · D_{g,ω}
    B_g_omega = B_g(rows_x, :);
    if ~isempty(rows_y)
        D_g_omega{omega} = D_g(rows_y, :);
    else
        D_g_omega{omega} = zeros(0, size(D_g, 2));
    end
    B_z_omega{omega} = B_g_omega - L_omega{omega} * D_g_omega{omega};

    % C_{g,ω}
    if ~isempty(rows_y)
        C_g_omega{omega} = C_g(rows_y, rows_x);
    else
        C_g_omega{omega} = [];
    end

    % C_{s,ω}, D_{s,ω}
    C_s_blocks = {};
    D_s_blocks = {};
    for s = idx
        if ~isempty(C_s{s})
            C_s_blocks{end+1} = C_s{s}; %#ok<AGROW>
            D_s_blocks{end+1} = D_s{s}; %#ok<AGROW>
        end
    end
    if ~isempty(C_s_blocks)
        C_s_omega{omega} = blkdiag(C_s_blocks{:});
        D_s_omega{omega} = vertcat(D_s_blocks{:});
    else
        C_s_omega{omega} = [];
        D_s_omega{omega} = [];
    end

    % L_{s,ω}
    dim_s = size(C_s_omega{omega}, 1);
    if dim_s > 0 && ~isempty(rows_y) && ~isempty(C_g_omega{omega})
        L_s_omega{omega} = L_omega{omega} * C_g_omega{omega} * pinv(C_s_omega{omega});
    elseif dim_s > 0
        L_s_omega{omega} = zeros(size(A_z_omega{omega}, 1), dim_s);
    else
        L_s_omega{omega} = [];
    end
end

end


function boxplot_grouped(data_cell, labels)
% boxplot_grouped  用 cell 数据绘制分组箱线图（兼容无 Statistics Toolbox 的情况）
%   当 Statistics Toolbox 不可用时，回退到简化的均值和范围图。

if exist('boxplot', 'file') == 2
    % 将 cell 数据转为分组向量
    all_data = [];
    all_group = [];
    for i = 1:length(data_cell)
        d = data_cell{i}(:);
        all_data = [all_data; d]; %#ok<AGROW>
        all_group = [all_group; i * ones(length(d), 1)]; %#ok<AGROW>
    end
    if ~isempty(all_data)
        boxplot(all_data, all_group, 'Labels', labels);
    end
else
    % 回退：绘制均值 ± 标准差 + 全距
    hold on;
    for i = 1:length(data_cell)
        d = data_cell{i}(:);
        x_pos = i;
        mu = mean(d);
        sigma = std(d);
        d_min = min(d);
        d_max = max(d);

        % 全距线
        plot([x_pos, x_pos], [d_min, d_max], 'k-', 'LineWidth', 1.0);
        % 均值标记
        plot(x_pos, mu, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        % ±1σ 范围
        plot([x_pos-0.2, x_pos+0.2], [mu-sigma, mu-sigma], 'b-', 'LineWidth', 1.5);
        plot([x_pos-0.2, x_pos+0.2], [mu+sigma, mu+sigma], 'b-', 'LineWidth', 1.5);
        plot([x_pos, x_pos], [mu-sigma, mu+sigma], 'b-', 'LineWidth', 1.5);
    end
    hold off;
    set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels);
    xlabel('故障幅值');
    ylabel('检出延迟（步数）');
    title('检出延迟分布（均值 ± 1σ + 全距）');
end

end
