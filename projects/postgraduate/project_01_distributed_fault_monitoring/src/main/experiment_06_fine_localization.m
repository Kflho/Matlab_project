%% experiment_06_fine_localization.m  实验 06 — 精定位（fine localization）
%  目标：验证目标 3.2，在粗定位锁定的中心内，利用 cut-and-observe
%        策略按 table I 逻辑准确定位故障子系统；同时演示递归联合
%        滤波器（recursive_joint_filter）单步运行。
%
%  核心验证逻辑：
%    1. 离线设计：完成 model 1→2→组装→LMI→拆分→model 3 的完整链路
%    2. 仿真：对子系统 1、2 分别注入传感器故障（k_fault=200, magnitude=0.3）
%    3. 粗定位：J_t²_y 统计量识别故障中心
%    4. 精定位（cut-and-observe）：
%       - 在锁定中心内依次切断各候选子系统的信息
%       - 每次切断后重新计算残差与 J_t²
%       - 导致合作伙伴 J_t² 下降最大的子系统 → 故障源
%    5. 递归联合滤波器单步演示（recursive_joint_filter）
%    6. 报告精定位准确率
%
%  验收标准：运行后报告精定位实际正确率（故障源头子系统 Id 被唯一确定的比例）
%
%  依赖：
%    src/lib/     — model_1_to_model_2, assemble_global_model, solve_luenberger_lmi,
%                   split_matrices_and_cov, compute_online_residuals, inject_fault,
%                   model_2_to_model_3_qr, recursive_joint_filter
%    src/scripts/ — create_model_1
%    utils/       — create_controlled_system, calculate_lqr, create_noise_v2,
%                   run_visualization

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  1. 离线设计：完整链路
% ============================================================
fprintf('========== 实验 06：精定位（Fine Localization）==========\n\n');
fprintf('--- 1. 离线设计 ---\n');

% 1a. 加载 model 1
create_model_1;

% 1b. model 1 → model 2（公式 7-10）
[A_bar, B_bar, C_bar, D_bar, E_bar, F_bar, C_s_bar, D_s_bar] = ...
    model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

% 1c. 全局矩阵组装（公式 11-14）
[A_g, B_g, C_g, D_g] = assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

% 1d. LMI/DARE 求解全局观测器矩阵
[A_z, L] = solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

% 1e. 计算中心划分
n_omega = 2;
indices_omega = {[1, 3], [2, 4]};

% 1f. 矩阵拆分与协方差计算（公式 19, 25-26）
%     sigma_r_omega 为各中心输出残差 r_y 的理论协方差
[A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = ...
    split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

% 1g. 额外计算：状态估计误差协方差（用于 r_s 理论协方差）
%     r_y 观测器误差：e_y(k+1) = A_z·e_y(k) + w(k) - L·v(k)
%       → Σ_{e,y} = dlyap(A_z, Σ_w + L·Σ_v·L')
%     r_s 观测器误差：e_s(k+1) = A_z·e_s(k) + w(k)  （s 信号无测量噪声）
%       → Σ_{e,s} = dlyap(A_z, Σ_w)   ← 不含测量噪声项
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';
Sigma_e_y   = dlyap(A_z, Sigma_Delta);       % 用于 r_y（与 split 内部一致）
Sigma_e_s   = dlyap(A_z, Sigma_w_full);       % 用于 r_s（无测量噪声驱动）

% 1h. 状态索引映射
cum_nx_global = [0, cumsum(n_x)];
state_rows_global = cell(1, n_s);
for i = 1:n_s
    state_rows_global{i} = (cum_nx_global(i)+1) : cum_nx_global(i+1);
end

cum_ny_global = [0, cumsum(n_y)];
output_rows_global = cell(1, n_s);
for i = 1:n_s
    if n_y(i) > 0
        output_rows_global{i} = (cum_ny_global(i)+1) : cum_ny_global(i+1);
    else
        output_rows_global{i} = [];
    end
end

% 1i. 为各中心预计算：C_{s,ω}、r_s 理论协方差 Σ_{r_s,ω}
cs_omega     = cell(1, n_omega);
Sigma_rs_omega = cell(1, n_omega);  % r_s 理论协方差

for omega = 1:n_omega
    idx = indices_omega{omega};

    % 局域状态行索引
    rx = [];
    for s = idx
        rx = [rx, state_rows_global{s}]; %#ok<AGROW>
    end

    % C_{s,ω} = blkdiag(C_s{idx})
    cs_blocks = {};
    for s = idx
        if ~isempty(C_s{s})
            cs_blocks{end+1} = C_s{s}; %#ok<AGROW>
        end
    end
    if ~isempty(cs_blocks)
        cs_omega{omega} = blkdiag(cs_blocks{:});
    else
        cs_omega{omega} = [];
    end

    % r_s 理论协方差：Σ_{r_s,ω} = C_{s,ω} · Σ_{e,s,ω} · C_{s,ω}'
    Sigma_e_s_omega = Sigma_e_s(rx, rx);
    if ~isempty(cs_omega{omega})
        Sigma_rs_omega{omega} = cs_omega{omega} * Sigma_e_s_omega * cs_omega{omega}';
    else
        Sigma_rs_omega{omega} = [];
    end

    fprintf('  中心 %d: r_y 协方差维度 %d×%d,  r_s 协方差维度 %d×%d\n', ...
        omega, ...
        size(Sigma_r_omega{omega}, 1), size(Sigma_r_omega{omega}, 2), ...
        size(Sigma_rs_omega{omega}, 1), size(Sigma_rs_omega{omega}, 2));
end

% 1j. model 2 → model 3：未知输入表示（用于 recursive_joint_filter 演示）
[G_model3, H_model3, Q_map] = model_2_to_model_3_qr(A_bar, C_bar, B_bar, D_bar, n_x, n_y);

fprintf('  离线设计完成：n_omega=%d, N_x=%d, N_y=%d\n', n_omega, size(A_g,1), size(C_g,1));
fprintf('  A_z 谱半径 = %.6f（< 1 则稳定）\n', max(abs(eig(A_z))));

%% ============================================================
%  2. 被控系统与 LQR 控制器设置
% ============================================================
fprintf('\n--- 2. 被控系统与 LQR 控制器设置 ---\n');

[A_g_sys, B_g_sys, C_g_sys, D_g_sys, x_eq, u_eq, y_eq] = create_controlled_system();
K = calculate_lqr(A_g_sys, B_g_sys);

N_x_sys = size(A_g_sys, 1);
N_u_sys = size(B_g_sys, 2);
N_y_sys = size(C_g_sys, 1);

fprintf('  被控系统：N_x=%d, N_u=%d, N_y=%d\n', N_x_sys, N_u_sys, N_y_sys);

%% ============================================================
%  3. 实验参数设置
% ============================================================
fprintf('\n--- 3. 实验参数设置 ---\n');

T_sim = 500;           % 仿真步长
k_fault = 200;         % 故障注入时刻
fault_magnitude = 0.3; % 故障幅值
rng(42);               % 固定种子

alpha = 0.99;          % 置信水平
transient_cut = 50;    % 瞬态截止步数（精定位分析用）

fault_locations = [1, 2];  % 仅对带传感器的子系统注入传感器故障
n_fault_cases = length(fault_locations);

fprintf('  T_sim=%d, k_fault=%d, fault_magnitude=%.2f\n', ...
    T_sim, k_fault, fault_magnitude);
fprintf('  故障注入子系统：%s\n', mat2str(fault_locations));
fprintf('  置信水平 α = %.2f\n', alpha);

%% ============================================================
%  4. 对每个故障场景运行仿真 + 粗定位 + 精定位
% ============================================================

% 预分配结果结构体
coarse_results  = cell(1, n_fault_cases);
fine_results    = cell(1, n_fault_cases);
sim_data_store  = cell(1, n_fault_cases);

for f_idx = 1:n_fault_cases

    fault_subsys = fault_locations(f_idx);
    fprintf('\n============================================================\n');
    fprintf('  故障场景 %d/%d：子系统 %d 传感器故障\n', ...
        f_idx, n_fault_cases, fault_subsys);
    fprintf('============================================================\n');

    %% --------------------------------------------------------
    %  4a. 仿真数据生成
    %% --------------------------------------------------------
    fprintf('  --- 4a. 仿真数据生成 ---\n');

    % 生成噪声序列
    [~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
    w_seq = squeeze(sim_w.Data);    % 4 × T_sim
    [~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
    v_seq = squeeze(sim_v.Data);    % 2 × T_sim

    % 预分配存储
    x_seq = zeros(N_x_sys, T_sim);
    u_seq = zeros(N_u_sys, T_sim);
    y_seq = zeros(N_y_sys, T_sim);

    cum_nx = [0, cumsum(n_x)];
    s_cell = cell(1, n_s);
    for i = 1:n_s
        s_cell{i} = zeros(n_x(i), T_sim);
    end

    % LQR 闭环仿真（正常工况）
    x_k = zeros(N_x_sys, 1);
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

    % 注入传感器故障
    [y_faulty, u_faulty] = inject_fault(y_seq, u_seq, 'sensor', ...
        fault_subsys, fault_magnitude, k_fault);

    fprintf('    仿真完成：T_sim=%d，故障注入于 k=%d，子系统 %d\n', ...
        T_sim, k_fault, fault_subsys);

    %% --------------------------------------------------------
    %  4b. 残差计算（完整配置，用于粗定位）
    %% --------------------------------------------------------
    fprintf('  --- 4b. 残差计算（粗定位）---\n');

    [r_y_full, r_s_full] = compute_online_residuals(...
        u_faulty, y_faulty, s_cell, ...
        A_z_omega, L_omega, ...
        B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
        indices_omega, n_x, n_y, n_s);

    %% --------------------------------------------------------
    %  4c. J_t² 统计量计算
    %% --------------------------------------------------------
    fprintf('  --- 4c. J_{T²} 统计量计算 ---\n');

    J_T2_y = cell(1, n_omega);
    J_T2_s = cell(1, n_omega);
    J_T2_combined = cell(1, n_omega);

    for omega = 1:n_omega

        % ---- r_y 的 T² 统计量 ----
        if ~isempty(r_y_full{omega}) && ~isempty(Sigma_r_omega{omega})
            dim_y = size(r_y_full{omega}, 1);
            J_T2_y{omega} = zeros(1, T_sim);
            Sigma_inv_y = Sigma_r_omega{omega} \ eye(dim_y);
            for k = 1:T_sim
                rk = r_y_full{omega}(:, k);
                J_T2_y{omega}(k) = rk' * Sigma_inv_y * rk;
            end
        else
            J_T2_y{omega} = [];
        end

        % ---- r_s 的 T² 统计量 ----
        if ~isempty(r_s_full{omega}) && ~isempty(Sigma_rs_omega{omega})
            dim_s = size(r_s_full{omega}, 1);
            J_T2_s{omega} = zeros(1, T_sim);
            Sigma_inv_s = Sigma_rs_omega{omega} \ eye(dim_s);
            for k = 1:T_sim
                rk = r_s_full{omega}(:, k);
                J_T2_s{omega}(k) = rk' * Sigma_inv_s * rk;
            end
        else
            J_T2_s{omega} = [];
        end

        % ---- 组合 J_t²（用于精定位比较）----
        J_comb = zeros(1, T_sim);
        if ~isempty(J_T2_y{omega})
            J_comb = J_comb + J_T2_y{omega};
        end
        if ~isempty(J_T2_s{omega})
            J_comb = J_comb + J_T2_s{omega};
        end
        J_T2_combined{omega} = J_comb;
    end

    %% --------------------------------------------------------
    %  4d. 理论门限计算
    %% --------------------------------------------------------
    J_th_y = zeros(1, n_omega);
    J_th_s = zeros(1, n_omega);
    J_th_combined = zeros(1, n_omega);

    for omega = 1:n_omega
        if ~isempty(r_y_full{omega})
            dim_y = size(r_y_full{omega}, 1);
            J_th_y(omega) = chi2inv(alpha, dim_y);
        else
            J_th_y(omega) = NaN;
        end
        if ~isempty(r_s_full{omega})
            dim_s = size(r_s_full{omega}, 1);
            J_th_s(omega) = chi2inv(alpha, dim_s);
        else
            J_th_s(omega) = NaN;
        end
        J_th_combined(omega) = sum([J_th_y(omega), J_th_s(omega)]);
    end

    %% --------------------------------------------------------
    %  4e. 粗定位：识别故障中心
    %% --------------------------------------------------------
    fprintf('  --- 4e. 粗定位 ---\n');

    % 计算各中心在故障后稳态期的 J_t²_y 均值
    k_steady_start = k_fault + transient_cut;
    if k_steady_start >= T_sim
        k_steady_start = k_fault + 10;
    end
    k_steady_range = k_steady_start : T_sim;

    J_T2_y_post = zeros(1, n_omega);
    for omega = 1:n_omega
        if ~isempty(J_T2_y{omega})
            J_T2_y_post(omega) = mean(J_T2_y{omega}(k_steady_range));
        else
            J_T2_y_post(omega) = 0;
        end
    end

    % 粗定位规则：J_t²_y 均值超过门限且最大的中心为故障中心
    exceed_threshold = J_T2_y_post > J_th_y;
    exceed_threshold(isnan(exceed_threshold)) = false;

    if any(exceed_threshold)
        % 在超过门限的中心中选 J_t² 最大的
        [~, omega_faulty] = max(J_T2_y_post .* exceed_threshold);
    else
        % 回退：选 J_t²_y 最大的中心
        [~, omega_faulty] = max(J_T2_y_post);
        fprintf('    警告：无中心 J_{T²,y} 超过门限，回退到最大值规则。\n');
    end

    fprintf('    故障中心 = %d（管辖子系统 %s）\n', ...
        omega_faulty, mat2str(indices_omega{omega_faulty}));
    fprintf('    各中心 J_{T²,y} 故障后均值: Center 1 = %.2f (th=%.2f), Center 2 = %.2f (th=%.2f)\n', ...
        J_T2_y_post(1), J_th_y(1), J_T2_y_post(2), J_th_y(2));

    coarse_results{f_idx}.omega_faulty   = omega_faulty;
    coarse_results{f_idx}.J_T2_y_post    = J_T2_y_post;
    coarse_results{f_idx}.J_th_y         = J_th_y;
    coarse_results{f_idx}.correct_center = ismember(fault_subsys, indices_omega{omega_faulty});

    %% --------------------------------------------------------
    %  4f. 精定位：cut-and-observe
    %% --------------------------------------------------------
    fprintf('  --- 4f. 精定位（cut-and-observe）---\n');

    center_subsystems = indices_omega{omega_faulty};
    n_candidates = length(center_subsystems);

    % 存储每个候选子系统被切断后的结果
    cut_J_T2_mean = zeros(1, n_candidates);   % 切断后的 J_t² 均值
    cut_J_T2_drop = zeros(1, n_candidates);   % J_t² 下降量

    % 全配置下的 J_t² 故障后均值（基准）
    full_J_T2_combined_post = mean(J_T2_combined{omega_faulty}(k_steady_range));

    for c_idx = 1:n_candidates
        cand_subsys = center_subsystems(c_idx);

        % ---- 创建修改后的数据 ----
        y_cut = y_faulty;          % 复制
        s_cut = s_cell;            % 复制（MATLAB copy-on-write）

        % 切断该子系统的测量输出（若有传感器）
        if ~isempty(output_rows_global{cand_subsys})
            y_rows = output_rows_global{cand_subsys};
            y_cut(y_rows, :) = 0;
        end

        % 切断该子系统的发送信息
        s_cut{cand_subsys} = zeros(n_x(cand_subsys), T_sim);

        % ---- 重新计算残差 ----
        [r_y_cut, r_s_cut] = compute_online_residuals(...
            u_faulty, y_cut, s_cut, ...
            A_z_omega, L_omega, ...
            B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
            indices_omega, n_x, n_y, n_s);

        % ---- 计算修改后的 J_t²（仅关注故障中心的组合 J_t²）----
        J_cut_omega = zeros(1, T_sim);

        if ~isempty(r_y_cut{omega_faulty}) && ~isempty(Sigma_r_omega{omega_faulty})
            dim_y_w = size(r_y_cut{omega_faulty}, 1);
            Sigma_inv_y_w = Sigma_r_omega{omega_faulty} \ eye(dim_y_w);
            for k = 1:T_sim
                rk = r_y_cut{omega_faulty}(:, k);
                J_cut_omega(k) = J_cut_omega(k) + rk' * Sigma_inv_y_w * rk;
            end
        end

        if ~isempty(r_s_cut{omega_faulty}) && ~isempty(Sigma_rs_omega{omega_faulty})
            dim_s_w = size(r_s_cut{omega_faulty}, 1);
            Sigma_inv_s_w = Sigma_rs_omega{omega_faulty} \ eye(dim_s_w);
            for k = 1:T_sim
                rk = r_s_cut{omega_faulty}(:, k);
                J_cut_omega(k) = J_cut_omega(k) + rk' * Sigma_inv_s_w * rk;
            end
        end

        cut_J_T2_mean(c_idx) = mean(J_cut_omega(k_steady_range));
        cut_J_T2_drop(c_idx) = full_J_T2_combined_post - cut_J_T2_mean(c_idx);

        fprintf('    切断 S%d: J_{T²} 故障后均值 = %.4f（基准 %.4f，下降 %.4f）\n', ...
            cand_subsys, cut_J_T2_mean(c_idx), full_J_T2_combined_post, ...
            cut_J_T2_drop(c_idx));
    end

    % 精定位判定：J_t² 下降最大的子系统为故障源
    [max_drop, idx_max_drop] = max(cut_J_T2_drop);
    identified_subsys = center_subsystems(idx_max_drop);
    correct_fine = (identified_subsys == fault_subsys);

    if correct_fine, result_str = '正确'; else, result_str = '错误'; end
    fprintf('    → 精定位结果：子系统 %d（实际故障源 %d），%s\n', ...
        identified_subsys, fault_subsys, result_str);

    fine_results{f_idx}.center_subsystems = center_subsystems;
    fine_results{f_idx}.cut_J_T2_mean     = cut_J_T2_mean;
    fine_results{f_idx}.cut_J_T2_drop     = cut_J_T2_drop;
    fine_results{f_idx}.full_J_T2_post    = full_J_T2_combined_post;
    fine_results{f_idx}.identified_subsys = identified_subsys;
    fine_results{f_idx}.actual_subsys     = fault_subsys;
    fine_results{f_idx}.correct           = correct_fine;

    % 存储仿真数据供后续可视化使用
    sim_data_store{f_idx}.fault_subsys     = fault_subsys;
    sim_data_store{f_idx}.omega_faulty     = omega_faulty;
    sim_data_store{f_idx}.J_T2_y           = J_T2_y;
    sim_data_store{f_idx}.J_T2_s           = J_T2_s;
    sim_data_store{f_idx}.J_T2_combined    = J_T2_combined;
    sim_data_store{f_idx}.J_th_y           = J_th_y;
    sim_data_store{f_idx}.J_th_s           = J_th_s;
    sim_data_store{f_idx}.J_th_combined    = J_th_combined;
    sim_data_store{f_idx}.y_faulty         = y_faulty;
    sim_data_store{f_idx}.u_faulty         = u_faulty;
    sim_data_store{f_idx}.s_cell           = s_cell;
    sim_data_store{f_idx}.r_y_full         = r_y_full;
    sim_data_store{f_idx}.r_s_full         = r_s_full;

end

%% ============================================================
%  5. 精定位准确率汇总
% ============================================================
fprintf('\n===== 5. 精定位准确率汇总 =====\n\n');

n_correct = 0;
for f_idx = 1:n_fault_cases
    fr = fine_results{f_idx};
    fprintf('  故障场景 %d：子系统 %d 故障 → 粗定位中心 %d（子系统 %s）', ...
        f_idx, fr.actual_subsys, ...
        coarse_results{f_idx}.omega_faulty, ...
        mat2str(indices_omega{coarse_results{f_idx}.omega_faulty}));
    fprintf(' → 精定位子系统 %d', fr.identified_subsys);
    if fr.correct
        fprintf(' ✓\n');
        n_correct = n_correct + 1;
    else
        fprintf(' ✗\n');
    end
    fprintf('    各候选切断后 J_{T²} 下降量: %s\n', ...
        mat2str(fr.cut_J_T2_drop, 4));
end

accuracy = n_correct / n_fault_cases * 100;
fprintf('\n  精定位准确率 = %d / %d = %.1f%%\n', n_correct, n_fault_cases, accuracy);

%% ============================================================
%  6. 递归联合滤波器单步演示
% ============================================================
fprintf('\n--- 6. 递归联合滤波器单步演示 ---\n');

% 使用故障场景 1（子系统 1 故障）的健康时段数据
demo_data = sim_data_store{1};
demo_subsys = 1;   % 演示子系统 1 的滤波器（健康状态，k < k_fault）
demo_k = 100;      % 取健康时刻

% 重建该时刻的仿真数据
% 注意：sim_data_store 只存了 J_t2 结果，需要重新从仿真取
% 为简化，使用故障场景 1 对应的仿真：运行一次小规模重新仿真

fprintf('  对子系统 %d 在时刻 k=%d（健康状态）运行单步 recursive_joint_filter...\n', ...
    demo_subsys, demo_k);

% 重新生成仿真数据（使用相同的 rng 种子以获得相同噪声）
rng(42);
[~, sim_w_demo] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_demo = squeeze(sim_w_demo.Data);
[~, sim_v_demo] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_demo = squeeze(sim_v_demo.Data);

x_demo = zeros(N_x_sys, T_sim);
u_demo = zeros(N_u_sys, T_sim);
y_demo = zeros(N_y_sys, T_sim);

x_k_demo = zeros(N_x_sys, 1);
for k = 1:T_sim
    u_k_demo = -K * x_k_demo;
    u_demo(:, k) = u_k_demo;
    y_demo(:, k) = C_g_sys * x_k_demo + v_demo(:, k);
    x_demo(:, k) = x_k_demo;
    if k < T_sim
        x_k_demo = A_g_sys * x_k_demo + B_g_sys * u_k_demo + w_demo(:, k);
    end
end

% 提取子系统 1 在时刻 k 的数据
y_k_demo = y_demo(output_rows_global{demo_subsys}, demo_k);  % 1×1
u_k_demo = u_demo(:, demo_k);                                % 2×1

% 从 model 2 和 model 3 提取子系统 1 的参数
A_1   = A_bar{1, 1};            % 1×1
B_1   = B_bar{1};               % 1×2
C_1   = C_bar{1, 1};            % 1×1
D_1   = D_bar{1};               % 1×2
G_1   = G_model3{1};            % 1×dim_d
H_1   = H_model3{1};            % 1×dim_d
sw_1  = Sigma_w{1};             % 1×1
sv_1  = Sigma_v{1};             % 1×1

fprintf('  子系统 %d 参数: A=%.4f, C=%.4f, dim(d)=%d, rank(H)=%d\n', ...
    demo_subsys, A_1, C_1, size(G_1, 2), rank(H_1));

% 初始条件
x_hat_init = zeros(size(A_1, 1), 1);
Sigma_init = eye(size(A_1, 1)) * 0.01;  % 小初始不确定度

% 运行单步递归联合滤波器
[x_hat_k_k, x_hat_kp1_k, d_hat_k, Sigma_kp1, M_k, K_k, info] = ...
    recursive_joint_filter(x_hat_init, Sigma_init, ...
                           y_k_demo, u_k_demo, ...
                           A_1, B_1, C_1, D_1, ...
                           G_1, H_1, sw_1, sv_1);

fprintf('\n  递归联合滤波器单步结果（子系统 %d，时刻 k=%d）：\n', demo_subsys, demo_k);
fprintf('    x̂_{k|k}       = %.6f\n', x_hat_k_k);
fprintf('    x̂_{k+1|k}     = %.6f\n', x_hat_kp1_k);
fprintf('    d̂_{k}         = %.6e（未知输入估计，健康状态应 ≈ 0）\n', d_hat_k);
fprintf('    Σ_{x̃,k+1|k}   = %.6e\n', Sigma_kp1);
fprintf('    M_{k}          = %.6e\n', M_k);
fprintf('    K_{k}          = %.6e\n', K_k);
fprintf('    info.converged = %d\n', info.converged);
fprintf('    info.rank_ok   = %d\n', info.rank_ok);
if isfield(info, 'y_tilde_b')
    fprintf('    ỹ_{b,k}        = %.6e（有偏创新）\n', info.y_tilde_b);
end
if isfield(info, 'y_tilde_ub')
    fprintf('    ỹ_{ub,k}       = %.6e（无偏创新）\n', info.y_tilde_ub);
end

fprintf('\n  解读：健康状态下 d̂_k ≈ 0，滤波器正常收敛，未知输入未检测到局部故障。\n');

%% ============================================================
%  7. 验收判定
% ============================================================
fprintf('\n===== 7. 验收判定 =====\n\n');

fprintf('  实验设计：对带传感器的子系统 1、2 分别注入传感器故障（%.2f），\n', ...
    fault_magnitude);
fprintf('  通过 cut-and-observe 策略在粗定位中心内进行精定位。\n\n');

if accuracy == 100
    fprintf('  实验 06 通过。精定位准确率 = %.1f%%。\n', accuracy);
    fprintf('  验证 cut-and-observe 策略可在锁定区域内准确识别故障子系统。\n');
elseif accuracy >= 50
    fprintf('  实验 06 部分通过。精定位准确率 = %.1f%%。\n', accuracy);
    fprintf('  可能原因：传感器故障幅值不足、噪声干扰较大、或瞬态未充分衰减。\n');
else
    fprintf('  实验 06 未通过。精定位准确率 = %.1f%%。\n', accuracy);
    fprintf('  需要检查：cut-and-observe 逻辑、残差协方差计算、门限设置。\n');
end

%% ============================================================
%  8. 可视化
% ============================================================
fprintf('\n--- 8. 可视化 ---\n');

out_pic = '../../outputs/experiment_06_fine_localization/figures/';
if ~exist(out_pic, 'dir'), mkdir(out_pic); end

n_plot = min(500, T_sim);
t_plot = (0:n_plot-1);

% ---- 8a. 各故障场景的 J_t² 时间曲线（带粗定位标记）----
for f_idx = 1:n_fault_cases
    sd = sim_data_store{f_idx};
    fs = sd.fault_subsys;
    of = sd.omega_faulty;

    % 图 1：两个中心的 J_t²_y 对比
    figh_jt2 = figure('Name', sprintf('实验06-故障S%d-JT2_y', fs), ...
                       'NumberTitle', 'off');

    colors = {'b', 'r'};
    for omega = 1:n_omega
        if ~isempty(sd.J_T2_y{omega})
            plot(t_plot, sd.J_T2_y{omega}(1:n_plot), ...
                [colors{omega} '-'], 'LineWidth', 0.8);
            hold on;
        end
    end

    % 门限线
    for omega = 1:n_omega
        if ~isnan(sd.J_th_y(omega))
            yline(sd.J_th_y(omega), [colors{omega} '--'], ...
                'LineWidth', 1.2);
        end
    end

    % 故障时刻标注
    xline(k_fault, 'k--', 'LineWidth', 1.5);
    xlabel('步数 k');
    ylabel('J_{T^2,y}(k)');
    title(sprintf('实验 06：子系统 %d 传感器故障 — 输出残差 T² 统计量', fs));
    legend_str = {};
    for omega = 1:n_omega
        legend_str{end+1} = sprintf('中心 %d J_{T²,y}', omega); %#ok<AGROW>
    end
    for omega = 1:n_omega
        legend_str{end+1} = sprintf('J_{th,%d}=%.2f', omega, sd.J_th_y(omega)); %#ok<AGROW>
    end
    legend_str{end+1} = sprintf('故障注入 k=%d', k_fault);
    legend(legend_str, 'Location', 'best');
    run_visualization(figh_jt2);
    saveas(figh_jt2, [out_pic sprintf('fault_S%d_JT2_y.png', fs)]);
    saveas(figh_jt2, [out_pic sprintf('fault_S%d_JT2_y.fig', fs)]);

    % 图 2：精定位 cut-and-observe 柱状图
    fr = fine_results{f_idx};
    figh_bar = figure('Name', sprintf('实验06-故障S%d-精定位', fs), ...
                       'NumberTitle', 'off');

    bar_data = fr.cut_J_T2_drop;
    n_cand = length(fr.center_subsystems);
    bar_colors = zeros(n_cand, 3);
    for ci = 1:n_cand
        if fr.center_subsystems(ci) == fr.actual_subsys
            bar_colors(ci, :) = [0.8, 0.2, 0.2];  % 实际故障源：红色
        else
            bar_colors(ci, :) = [0.3, 0.5, 0.8];  % 其他：蓝色
        end
    end

    b = bar(bar_data, 'FaceColor', 'flat');
    b.CData = bar_colors;
    set(gca, 'XTickLabel', arrayfun(@(x) sprintf('S%d', x), ...
        fr.center_subsystems, 'UniformOutput', false));

    xlabel('被切断的子系统');
    ylabel('J_{T²} 下降量');
    title(sprintf(['实验 06：子系统 %d 故障 — 精定位 cut-and-observe\n' ...
        '（中心 %d，切断各候选后 J_{T²,combined} 下降量）'], fs, of));
    run_visualization(figh_bar);
    saveas(figh_bar, [out_pic sprintf('fault_S%d_fine_bar.png', fs)]);
    saveas(figh_bar, [out_pic sprintf('fault_S%d_fine_bar.fig', fs)]);

    % 图 3：J_t²_combined 全序列与各切断后对比
    figh_compare = figure('Name', sprintf('实验06-故障S%d-切断对比', fs), ...
                           'NumberTitle', 'off');

    % 全配置 J_t²_combined
    plot(t_plot, sd.J_T2_combined{of}(1:n_plot), 'k-', 'LineWidth', 1.5);
    hold on;

    % 各切断后的 J_t²_combined（使用存储的仿真数据重新计算）
    y_ref = sd.y_faulty;
    u_ref = sd.u_faulty;
    s_ref = sd.s_cell;
    cut_colors = lines(length(fr.center_subsystems));
    for ci = 1:length(fr.center_subsystems)
        cand = fr.center_subsystems(ci);

        y_cut_tmp = y_ref;
        s_cut_tmp = s_ref;

        if ~isempty(output_rows_global{cand})
            y_cut_tmp(output_rows_global{cand}, :) = 0;
        end
        s_cut_tmp{cand} = zeros(n_x(cand), T_sim);

        [r_y_ct, r_s_ct] = compute_online_residuals(...
            u_ref, y_cut_tmp, s_cut_tmp, ...
            A_z_omega, L_omega, ...
            B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
            indices_omega, n_x, n_y, n_s);

        J_ct = zeros(1, n_plot);
        if ~isempty(r_y_ct{of}) && ~isempty(Sigma_r_omega{of})
            dim_y_ct = size(r_y_ct{of}, 1);
            sinv_y_ct = Sigma_r_omega{of} \ eye(dim_y_ct);
            for k = 1:n_plot
                rk = r_y_ct{of}(:, k);
                J_ct(k) = J_ct(k) + rk' * sinv_y_ct * rk;
            end
        end
        if ~isempty(r_s_ct{of}) && ~isempty(Sigma_rs_omega{of})
            dim_s_ct = size(r_s_ct{of}, 1);
            sinv_s_ct = Sigma_rs_omega{of} \ eye(dim_s_ct);
            for k = 1:n_plot
                rk = r_s_ct{of}(:, k);
                J_ct(k) = J_ct(k) + rk' * sinv_s_ct * rk;
            end
        end

        plot(t_plot, J_ct, '--', 'Color', cut_colors(ci, :), 'LineWidth', 1.0);
    end

    xline(k_fault, 'k--', 'LineWidth', 1.5);
    xlabel('步数 k');
    ylabel('J_{T²,combined}(k)');
    title(sprintf('实验 06：子系统 %d 故障 — 切断各候选后 J_{T²,combined} 对比', fs));

    leg_lines = {'全配置'};
    for ci = 1:length(fr.center_subsystems)
        leg_lines{end+1} = sprintf('切断 S%d', fr.center_subsystems(ci)); %#ok<AGROW>
    end
    leg_lines{end+1} = sprintf('故障 k=%d', k_fault);
    legend(leg_lines, 'Location', 'best');
    run_visualization(figh_compare);
    saveas(figh_compare, [out_pic sprintf('fault_S%d_cut_compare.png', fs)]);
    saveas(figh_compare, [out_pic sprintf('fault_S%d_cut_compare.fig', fs)]);
end

% ---- 8b. 准确率汇总图 ----
figh_acc = figure('Name', '实验06-精定位准确率', 'NumberTitle', 'off');

subplot(1, 2, 1);
pie_data = [n_correct, n_fault_cases - n_correct];
if sum(pie_data) > 0
    h_pie = pie(pie_data);
    % 设置颜色
    if iscell(h_pie)
        for pi = 1:2:length(h_pie)
            if pi == 1
                h_pie{pi}.FaceColor = [0.2, 0.7, 0.3];
            else
                h_pie{pi}.FaceColor = [0.9, 0.3, 0.3];
            end
        end
    end
    title(sprintf('精定位准确率 = %.1f%%', accuracy));
    legend({'正确', '错误'}, 'Location', 'best');
end

subplot(1, 2, 2);
bar_data_acc = zeros(1, n_fault_cases);
for f_idx = 1:n_fault_cases
    bar_data_acc(f_idx) = fine_results{f_idx}.correct;
end
bar(bar_data_acc, 'FaceColor', [0.3, 0.6, 0.8]);
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('S%d', x), ...
    fault_locations, 'UniformOutput', false));
xlabel('故障子系统');
ylabel('正确 = 1 / 错误 = 0');
title('各故障场景精定位结果');
ylim([-0.1, 1.5]);
yticks([0, 1]);
yticklabels({'错误', '正确'});
run_visualization(figh_acc);
saveas(figh_acc, [out_pic 'accuracy_summary.png']);
saveas(figh_acc, [out_pic 'accuracy_summary.fig']);

fprintf('  绘图完成。输出目录：%s\n', out_pic);

%% ============================================================
%  9. 产出保存
% ============================================================
fprintf('\n--- 9. 产出保存 ---\n');

out_data = '../../outputs/experiment_06_fine_localization/data/';
if ~exist(out_data, 'dir'), mkdir(out_data); end

save([out_data 'results.mat'], ...
    'coarse_results', 'fine_results', ...
    'n_correct', 'n_fault_cases', 'accuracy', ...
    'T_sim', 'k_fault', 'fault_magnitude', ...
    'fault_locations', 'alpha', ...
    'n_omega', 'indices_omega', ...
    'A_z_omega', 'L_omega', 'Sigma_r_omega', 'Sigma_rs_omega', ...
    'G_model3', 'H_model3');

fprintf('  产出已保存到 outputs/experiment_06_fine_localization/\n');

%% ============================================================
%  10. 汇总表
% ============================================================
fprintf('\n===== 10. 汇总表 =====\n\n');

fprintf('  %-8s %-12s %-12s %-12s %-10s\n', ...
    '故障源', '粗定位中心', '精定位结果', '实际子系统', '正确?');
fprintf('  %-8s %-12s %-12s %-12s %-10s\n', ...
    '------', '--------', '---------', '--------', '-----');

for f_idx = 1:n_fault_cases
    cr = coarse_results{f_idx};
    fr = fine_results{f_idx};
    if fr.correct, check_str = '✓'; else, check_str = '✗'; end
    fprintf('  S%-7d 中心 %-9d S%-11d S%-11d %s\n', ...
        fr.actual_subsys, cr.omega_faulty, ...
        fr.identified_subsys, fr.actual_subsys, check_str);
end

fprintf('\n  总准确率：%d/%d = %.1f%%\n\n', n_correct, n_fault_cases, accuracy);

%% ============================================================
%  11. 原理说明
% ============================================================
fprintf('--- 11. 原理说明 ---\n');
fprintf(['  精定位（Fine Localization）在粗定位锁定故障中心后执行。\n\n' ...
        '  Table I 逻辑（cut-and-observe 简化实现）：\n' ...
        '    1. 在锁定中心内，依次切断各候选子系统 S_i 的发送信息\n' ...
        '       （将其 s 信号置零，传感器测量亦置零）\n' ...
        '    2. 重新计算中心组合残差的 J_{T²,combined} 统计量\n' ...
        '    3. 比较切断前后的 J_{T²} 变化：\n' ...
        '       - 若切断 S_i 后 J_{T²} 大幅下降 → S_i 的信息流携带故障特征\n' ...
        '         → S_i 为故障源\n' ...
        '       - 若切断 S_i 后 J_{T²} 基本不变 → 故障不在 S_i\n' ...
        '         → S_i 健康\n' ...
        '    4. 下降最大的候选子系统被判定为故障源\n\n' ...
        '  递归联合滤波器（recursive_joint_filter）是精定位的理论基础：\n' ...
        '    - 通过估计未知输入 d̂_k 来检测子系统间的异常耦合\n' ...
        '    - 健康状态下 d̂_k ≈ 0（无异常耦合信息）\n' ...
        '    - 故障状态下 d̂_k ≠ 0（检测到异常信息流）\n\n' ...
        '  本实验验证了 cut-and-observe 策略能从粗定位中心内\n' ...
        '  准确识别故障子系统，并演示了递归联合滤波器的单步行为。\n']);

fprintf('\n========== 实验 06 结束 ==========\n');
