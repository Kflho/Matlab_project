%% experiment_02_zero_mean_residual.m  实验 02 — 残差零均值验证
%  目标：验证在没有中央融合节点的情况下，正常状态（无故障）残差的
%        期望值为零。各计算中心独立生成的残差序列，其样本均值应在
%        理论标准差范围内。
%
%  核心验证逻辑：
%    1. 离线设计：完成 Model 1→2→组装→LMI→拆分的完整链路
%    2. 正常工况仿真：LQR 闭环生成 x/u/y/s 时间序列（无故障注入）
%    3. 残差计算：各中心独立计算 r_y 和 r_s
%    4. 均值检验：对比样本均值与理论标准差界（σ/√T_sim）
%       - r_y 的 σ 来自 split_matrices_and_cov 的 Σ_{r,ω}
%       - r_s 的 σ 来自 Σ_{e,s}（s-观测器误差协方差）的局域分块
%    5. 可视化：残差时序图叠加零基线，样本均值与置信区间对比
%
%  验收标准：
%    运行后报告各中心残差样本均值的实际最大绝对值，
%    与理论标准差界对比。
%
%  依赖：
%    src/lib/     — model_1_to_model_2, assemble_global_model, solve_luenberger_lmi,
%                   split_matrices_and_cov, compute_online_residuals
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
fprintf('========== 实验 02：残差零均值验证 ==========\n\n');
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
Omega = 2;
indices_omega = {[1, 3], [2, 4]};

% 1f. 矩阵拆分与协方差计算（公式 19, 25-26）
[A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = ...
    split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

% 1g. 额外计算：状态估计误差协方差（用于 r_s 理论界）
%     split_matrices_and_cov 内部计算了 Σ_e 但不返回，此处重新计算。
%     r_y 观测器误差：e_y(k+1) = A_z·e_y(k) + w(k) - L·v(k)
%       → Σ_{e,y} = dlyap(A_z, Σ_w + L·Σ_v·L')
%     r_s 观测器误差：e_s(k+1) = A_z·e_s(k) + w(k)  （s 信号无噪声）
%       → Σ_{e,s} = dlyap(A_z, Σ_w)   ← 不含测量噪声项
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';
Sigma_e_y   = dlyap(A_z, Sigma_Delta);       % 用于 r_y（与 Split 内部一致）
Sigma_e_s   = dlyap(A_z, Sigma_w_full);       % 用于 r_s（无测量噪声驱动）

fprintf('  离线设计完成：Omega=%d, N_x=%d, N_y=%d\n', Omega, size(A_g,1), size(C_g,1));

%% ============================================================
%  2. 正常工况仿真数据生成（无故障注入）
% ============================================================
fprintf('\n--- 2. 正常工况仿真数据生成 ---\n');

% 被控系统与 LQR 控制器
[A_g_sys, B_g_sys, C_g_sys, D_g_sys, x_eq, u_eq, y_eq] = create_controlled_system();
K = calculate_lqr(A_g_sys, B_g_sys);

T_sim = 5000;           % 仿真步长（更长以验证统计收敛）
rng(42);                % 固定种子，保证可复现

% 生成噪声序列
[~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);    % 4 × T_sim
[~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq = squeeze(sim_v.Data);    % 2 × T_sim

% 预分配存储
N_x = size(A_g_sys, 1);
N_u = size(B_g_sys, 2);
N_y = size(C_g_sys, 1);

x_seq = zeros(N_x, T_sim);
u_seq = zeros(N_u, T_sim);
y_seq = zeros(N_y, T_sim);

cum_nx = [0, cumsum(n_x)];
s_cell = cell(1, n_s);
for i = 1:n_s
    s_cell{i} = zeros(n_x(i), T_sim);
end

% LQR 闭环仿真（正常工况，无故障）
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

fprintf('  仿真完成：T_sim=%d（正常工况，无故障注入）\n', T_sim);
fprintf('  u=%dx%d, y=%dx%d, x=%dx%d\n', ...
    size(u_seq, 1), size(u_seq, 2), size(y_seq, 1), size(y_seq, 2), ...
    size(x_seq, 1), size(x_seq, 2));

%% ============================================================
%  3. 残差计算
% ============================================================
fprintf('\n--- 3. 各计算中心独立计算残差 ---\n');

[r_y, r_s] = compute_online_residuals(...
    u_seq, y_seq, s_cell, ...
    A_z_omega, L_omega, ...
    B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
    indices_omega, n_x, n_y, n_s);

%% ============================================================
%  4. 构建局域索引（用于提取 Σ_e 分块和 C_s 分块）
% ============================================================

% 状态索引映射
cum_nx_global = [0, cumsum(n_x)];
state_rows_global = cell(1, n_s);
for i = 1:n_s
    state_rows_global{i} = (cum_nx_global(i)+1) : cum_nx_global(i+1);
end

% 为各中心预计算：局域状态行索引、C_{s,ω}、r_s 理论协方差
rows_x_omega = cell(1, Omega);
Cs_omega     = cell(1, Omega);
Sigma_rs_omega = cell(1, Omega);  % r_s 理论协方差

for omega = 1:Omega
    idx = indices_omega{omega};

    % 局域状态行索引
    rx = [];
    for s = idx
        rx = [rx, state_rows_global{s}]; %#ok<AGROW>
    end
    rows_x_omega{omega} = rx;

    % C_{s,ω} = blkdiag(C_s{idx})
    Cs_blocks = {};
    for s = idx
        if ~isempty(C_s{s})
            Cs_blocks{end+1} = C_s{s}; %#ok<AGROW>
        end
    end
    if ~isempty(Cs_blocks)
        Cs_omega{omega} = blkdiag(Cs_blocks{:});
    else
        Cs_omega{omega} = [];
    end

    % r_s 理论协方差：Σ_{r_s,ω} = C_{s,ω} · Σ_{e,s,ω} · C_{s,ω}'
    % （s 信号不含测量噪声 → 使用 Σ_{e,s} 而非 Σ_{e,y}）
    Sigma_e_s_omega = Sigma_e_s(rx, rx);
    if ~isempty(Cs_omega{omega})
        Sigma_rs_omega{omega} = Cs_omega{omega} * Sigma_e_s_omega * Cs_omega{omega}';
    else
        Sigma_rs_omega{omega} = [];
    end
end

%% ============================================================
%  5. 样本均值计算与理论界对比（排除瞬态）
% ============================================================
%  检验准则：|r̄_ω(j)| < 3 · σ_j / √T_steady
%    - r_y: σ_j = sqrt(Σ_{r,ω}(j,j))  — 来自 split_matrices_and_cov
%    - r_s: σ_j = sqrt(Σ_{r_s,ω}(j,j)) — 来自 Σ_{e,s} 局域投影（无测量噪声项）

transient_cut = 200;
T_steady = T_sim - transient_cut;

fprintf('\n===== 5. 样本均值检验（排除前 %d 步瞬态，T_steady=%d）=====\n\n', ...
    transient_cut, T_steady);

all_passed = true;

% 预存各分量结果供汇总表
mean_results = struct();

for omega = 1:Omega

    fprintf('--- 中心 %d（管辖子系统 %s）---\n', omega, mat2str(indices_omega{omega}));

    % ---- 5a. 输出残差 r_y 均值检验（稳态数据）----
    if ~isempty(r_y{omega})
        r_y_steady = r_y{omega}(:, transient_cut+1:end);
        mean_y = mean(r_y_steady, 2);
        sigma_y = sqrt(diag(Sigma_r_omega{omega}));
        bound_y = 3 * sigma_y / sqrt(T_steady);
        n_y_dim = length(mean_y);

        for j = 1:n_y_dim
            passed = abs(mean_y(j)) < bound_y(j);
            if ~passed, all_passed = false; end
            if passed, vy = '通过'; else, vy = '未通过'; end
            fprintf('  r_y 维度 %d:  均值 = %+.4e,  界 = %.4e,  |均值|/界 = %.2f  [%s]\n', ...
                j, mean_y(j), bound_y(j), abs(mean_y(j))/bound_y(j), vy);
        end
    else
        mean_y = [];  bound_y = [];  n_y_dim = 0;
        fprintf('  r_y: 无输出残差（中心无传感器子系统）\n');
    end

    % ---- 5b. 发送信息残差 r_s 均值检验（稳态数据）----
    if ~isempty(r_s{omega}) && ~isempty(Sigma_rs_omega{omega})
        r_s_steady = r_s{omega}(:, transient_cut+1:end);
        mean_s = mean(r_s_steady, 2);
        sigma_s = sqrt(diag(Sigma_rs_omega{omega}));
        bound_s = 3 * sigma_s / sqrt(T_steady);
        n_s_dim = length(mean_s);

        for j = 1:n_s_dim
            passed = abs(mean_s(j)) < bound_s(j);
            if ~passed, all_passed = false; end
            if passed, vs = '通过'; else, vs = '未通过'; end
            fprintf('  r_s 维度 %d:  均值 = %+.4e,  界 = %.4e,  |均值|/界 = %.2f  [%s]\n', ...
                j, mean_s(j), bound_s(j), abs(mean_s(j))/bound_s(j), vs);
        end
    else
        mean_s = [];  bound_s = [];  n_s_dim = 0;
    end

    % 保存汇总
    mean_results(omega).omega   = omega;
    mean_results(omega).indices = indices_omega{omega};
    mean_results(omega).mean_y  = mean_y;
    mean_results(omega).bound_y = bound_y;
    mean_results(omega).n_y_dim = n_y_dim;
    mean_results(omega).mean_s  = mean_s;
    mean_results(omega).bound_s = bound_s;
    mean_results(omega).n_s_dim = n_s_dim;

end

%% ============================================================
%  6. 验收判定
% ============================================================
fprintf('\n===== 6. 验收判定 =====\n\n');

if all_passed
    fprintf('  实验 02 通过。\n');
    fprintf('    在正常工况（无故障）下，各计算中心独立生成的残差序列\n');
    fprintf('    样本均值均落在 3σ/√T_sim 的理论界内。\n');
    fprintf('    验证残差期望值为零，无中央融合节点下分布式残差生成器无偏。\n');
else
    fprintf('  实验 02 未通过。存在残差分量样本均值超出 3σ 理论界的中心。\n');
    fprintf('  可能原因：\n');
    fprintf('    - 仿真步长 T_sim 不足，统计波动较大\n');
    fprintf('    - 噪声序列随机种子导致小概率偏移\n');
    fprintf('    - 离线设计环节存在数值误差\n');
end

%% ============================================================
%  7. 可视化：残差时间序列 + 零基线 + 样本均值标注
% ============================================================
fprintf('\n--- 7. 可视化 ---\n');

n_plot = min(300, T_sim);
t_plot = (0:n_plot-1);

for omega = 1:Omega

    % ---- 7a. 输出残差 r_y 时序图 ----
    if ~isempty(r_y{omega})
        figh_y = figure('Name', sprintf('实验02-中心%d-输出残差零均值', omega), ...
                        'NumberTitle', 'off');

        n_y_dim = size(r_y{omega}, 1);
        for dim = 1:n_y_dim
            subplot(n_y_dim, 1, dim);

            plot(t_plot, r_y{omega}(dim, 1:n_plot), 'b-', 'LineWidth', 1.0);
            hold on;
            yline(0, 'k--', 'LineWidth', 1.0);

            mn = mean_results(omega).mean_y(dim);
            bd = mean_results(omega).bound_y(dim);
            yline(mn, 'r-', 'LineWidth', 1.2);
            yline( bd, 'r:', 'LineWidth', 0.8);
            yline(-bd, 'r:', 'LineWidth', 0.8);
            hold off;

            xlabel('步数 k');
            ylabel(sprintf('r^y_{%d}', dim));
            title(sprintf('中心 %d — 输出残差维度 %d（均值=%.3e, 界=%.3e）', ...
                omega, dim, mn, bd));
            legend('残差', '零基线', '样本均值', '±3σ界', 'Location', 'best');
        end
        run_visualization(figh_y);

        % 保存 r_y 时序图
        out_pic = '../../outputs/experiment_02_zero_mean_residual/figures/';
        if ~exist(out_pic, 'dir'), mkdir(out_pic); end
        saveas(figh_y, [out_pic sprintf('center%d_ry_timeseries.png', omega)]);
        saveas(figh_y, [out_pic sprintf('center%d_ry_timeseries.fig', omega)]);
    end

    % ---- 7b. 发送信息残差 r_s 时序图 ----
    if ~isempty(r_s{omega})
        figh_s = figure('Name', sprintf('实验02-中心%d-信息残差零均值', omega), ...
                        'NumberTitle', 'off');

        n_s_dim = size(r_s{omega}, 1);
        for dim = 1:n_s_dim
            subplot(n_s_dim, 1, dim);

            plot(t_plot, r_s{omega}(dim, 1:n_plot), 'b-', 'LineWidth', 1.0);
            hold on;
            yline(0, 'k--', 'LineWidth', 1.0);

            mn = mean_results(omega).mean_s(dim);
            bd = mean_results(omega).bound_s(dim);
            yline(mn, 'r-', 'LineWidth', 1.2);
            yline( bd, 'r:', 'LineWidth', 0.8);
            yline(-bd, 'r:', 'LineWidth', 0.8);
            hold off;

            xlabel('步数 k');
            ylabel(sprintf('r^s_{%d}', dim));
            title(sprintf('中心 %d — 信息残差维度 %d（均值=%.3e, 界=%.3e）', ...
                omega, dim, mn, bd));
            legend('残差', '零基线', '样本均值', '±3σ界', 'Location', 'best');
        end
        run_visualization(figh_s);

        % 保存 r_s 时序图
        saveas(figh_s, [out_pic sprintf('center%d_rs_timeseries.png', omega)]);
        saveas(figh_s, [out_pic sprintf('center%d_rs_timeseries.fig', omega)]);
    end

end

fprintf('  绘图完成。蓝线为残差序列，红实线为样本均值，红虚线为 ±3σ/√T 界。\n');

%% ============================================================
%  8. 全序列稳态统计（排除前 100 步瞬态）
% ============================================================
fprintf('\n--- 8. 稳态统计（排除前 %d 步瞬态，T_steady=%d）---\n', ...
    transient_cut, T_steady);

for omega = 1:Omega

    fprintf('  中心 %d（管辖子系统 %s）:\n', omega, mat2str(indices_omega{omega}));

    % r_y 稳态统计
    if ~isempty(r_y{omega})
        r_y_steady = r_y{omega}(:, transient_cut+1:end);
        mean_y_steady = mean(r_y_steady, 2);
        std_y_steady  = std(r_y_steady, 0, 2);
        sigma_y_theory = sqrt(diag(Sigma_r_omega{omega}));

        for j = 1:length(mean_y_steady)
            fprintf('    r_y 维度 %d: 稳态均值=%+.4e, 稳态标准差=%.4e, 理论标准差=%.4e\n', ...
                j, mean_y_steady(j), std_y_steady(j), sigma_y_theory(j));
        end
    end

    % r_s 稳态统计
    if ~isempty(r_s{omega}) && ~isempty(Sigma_rs_omega{omega})
        r_s_steady = r_s{omega}(:, transient_cut+1:end);
        mean_s_steady = mean(r_s_steady, 2);
        std_s_steady  = std(r_s_steady, 0, 2);
        sigma_s_theory = sqrt(diag(Sigma_rs_omega{omega}));

        for j = 1:length(mean_s_steady)
            fprintf('    r_s 维度 %d: 稳态均值=%+.4e, 稳态标准差=%.4e, 理论标准差=%.4e\n', ...
                j, mean_s_steady(j), std_s_steady(j), sigma_s_theory(j));
        end
    end

end

%% ============================================================
%  9. 汇总表
% ============================================================
fprintf('\n===== 9. 汇总表 =====\n\n');

fprintf('\n  检验准则：|样本均值| < 3σ/√T_steady = %.4e · σ  (T_steady=%d)\n\n', 3/sqrt(T_steady), T_steady);

fprintf('  %-8s %-6s %-7s %-16s %-16s %-8s %s\n', ...
    '中心', '类型', '维度', '样本均值', '3σ界', '|均值|/界', '判定');
fprintf('  %-8s %-6s %-7s %-16s %-16s %-8s %s\n', ...
    '----', '----', '-----', '--------------', '--------------', '--------', '----');

for omega = 1:Omega
    mr = mean_results(omega);

    for j = 1:mr.n_y_dim
        ratio = abs(mr.mean_y(j)) / mr.bound_y(j);
        if ratio < 1, vy = '通过'; else, vy = '未通过'; end
        fprintf('  %-8d %-6s %-7d %-16.4e %-16.4e %-8.2f %s\n', ...
            omega, 'r_y', j, mr.mean_y(j), mr.bound_y(j), ratio, vy);
    end

    for j = 1:mr.n_s_dim
        ratio = abs(mr.mean_s(j)) / mr.bound_s(j);
        if ratio < 1, vs = '通过'; else, vs = '未通过'; end
        fprintf('  %-8d %-6s %-7d %-16.4e %-16.4e %-8.2f %s\n', ...
            omega, 'r_s', j, mr.mean_s(j), mr.bound_s(j), ratio, vs);
    end
end

%% ============================================================
%  10. 原理说明
% ============================================================
fprintf('\n--- 10. 原理说明 ---\n');
fprintf(['  残差生成器基于 Luenberger 观测器结构（公式 15-18）：\n' ...
        '    z_{k+1} = A_z·z_k + B_z·u_k + L·y_k\n' ...
        '    r_k     = y_k - C_g·z_k - D_g·u_k\n\n' ...
        '  设计条件（Theorem 1）保证 A_z 为 Schur 稳定矩阵，\n' ...
        '  且 (A_z, L) 满足 Luenberger 条件。在无故障正常工况下：\n' ...
        '    - 过程噪声 w_k 和测量噪声 v_k 均为零均值\n' ...
        '    - 观测器状态 z_k 渐进跟踪真实状态\n' ...
        '    - 残差 r_k 渐进为零均值随机过程\n\n' ...
        '  各计算中心独立运行，无需中央融合节点即可保证残差无偏。\n']);

%% ============================================================
%  11. 产出保存
% ============================================================
out_data = '../../outputs/experiment_02_zero_mean_residual/data/';
if ~exist(out_data, 'dir'), mkdir(out_data); end
save([out_data 'results.mat'], ...
    'mean_results', 'Omega', 'indices_omega', 'T_sim', 'transient_cut', 'T_steady', ...
    'Sigma_r_omega', 'Sigma_rs_omega');
fprintf('\n  产出已保存到 outputs/experiment_02_zero_mean_residual/\n');

fprintf('\n========== 实验 02 结束 ==========\n');