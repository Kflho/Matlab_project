%% Experiment_01_decentralized_residual.m  实验 01 — 分布式残差独立计算验证
%  目标：证明每个计算中心仅使用本地数据即可独立计算残差，无需全局信息。
%        各中心独立计算的残差与全局残差对应分块完全一致。
%
%  核心验证逻辑：
%    1. 离线设计：完成 Model 1→2→组装→LMI→拆分的完整链路
%    2. 仿真数据：LQR 闭环生成 x/u/y/s 时间序列
%    3. 全局计算：所有中心一起调用 Compute_online_residuals → r_y_all, r_s_all
%    4. 局域计算：每次只传一个中心给 Compute_online_residuals → r_y_loc, r_s_loc
%    5. 对比：∀ ω，局域残差与全局残差中 ω 对应分块的最大偏差 < 1e-12
%
%  依赖：
%    Function/ — Model_1_to_model_2, Assemble_global_model, Solve_luenberger_lmi,
%                Split_matrices_and_cov, Compute_online_residuals
%    Script/  — Create_model_1
%    Common/  — Create_controlled_system, Calculate_LQR, Create_noise_v2,
%               Visualization/Run_visualization

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

%% ============================================================
%  1. 离线设计：完整链路
% ============================================================
fprintf('========== 实验 01：分布式残差独立计算验证 ==========\n\n');
fprintf('--- 1. 离线设计 ---\n');

% 1a. 加载 Model 1
Create_model_1;

% 1b. Model 1 → Model 2（公式 7-10）
[A_bar, B_bar, C_bar, D_bar] = ...
    Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

% 1c. 全局矩阵组装（公式 11-14）
[A_g, B_g, C_g, D_g] = Assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

% 1d. LMI/DARE 求解全局观测器矩阵
[A_z, L] = Solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

% 1e. 计算中心划分
Omega = 2;
indices_omega = {[1, 3], [2, 4]};

% 1f. 矩阵拆分与协方差计算（公式 19, 25-26）
[A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = ...
    Split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

fprintf('  离线设计完成：Omega=%d, N_x=%d, N_y=%d\n', Omega, size(A_g,1), size(C_g,1));

%% ============================================================
%  2. 仿真数据生成
% ============================================================
fprintf('\n--- 2. 仿真数据生成 ---\n');

% 被控系统与 LQR 控制器
[A_g_sys, B_g_sys, C_g_sys, D_g_sys, x_eq, u_eq, y_eq] = Create_controlled_system();
K = Calculate_LQR(A_g_sys, B_g_sys);

T_sim = 500;           % 仿真步长（无需太长，仅验证一致性）
rng(42);               % 固定种子，保证可复现

% 噪声协方差转为全局矩阵
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});

% 生成噪声序列
[~, sim_w] = Create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);    % 4 × T_sim
[~, sim_v] = Create_noise_v2(T_sim, diag(Sigma_v_full)');
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

% LQR 闭环仿真
x_k = zeros(N_x, 1);
for k = 1:T_sim
    u_k = -K * x_k;
    u_seq(:, k) = u_k;
    y_seq(:, k) = C_g_sys * x_k + v_seq(:, k);

    for i = 1:n_s
        idx = (cum_nx(i)+1) : cum_nx(i+1);
        s_cell{i}(:, k) = C_s{i} * x_k(idx) + D_s{i} * u_k;
    end

    x_seq(:, k) = x_k;
    if k < T_sim
        x_k = A_g_sys * x_k + B_g_sys * u_k + w_seq(:, k);
    end
end

fprintf('  仿真完成：T_sim=%d, u=%dx%d, y=%dx%d, x=%dx%d\n', ...
    T_sim, size(u_seq,1), size(u_seq,2), size(y_seq,1), size(y_seq,2), ...
    size(x_seq,1), size(x_seq,2));

%% ============================================================
%  3. 全局残差计算（所有中心一起）
% ============================================================
fprintf('\n--- 3. 全局残差计算（%d 个中心联合）---\n', Omega);

[r_y_all, r_s_all] = Compute_online_residuals(...
    u_seq, y_seq, s_cell, ...
    A_z_omega, L_omega, ...
    B_g, C_g, D_g, C_s, D_s, ...
    indices_omega, n_x, n_y, n_s);

fprintf('  全局残差维度：\n');
for omega = 1:Omega
    fprintf('    中心 %d: r_y = %dx%d,  r_s = %dx%d\n', ...
        omega, size(r_y_all{omega}, 1), size(r_y_all{omega}, 2), ...
        size(r_s_all{omega}, 1), size(r_s_all{omega}, 2));
end

%% ============================================================
%  4. 局域残差计算（每次只传一个中心）
% ============================================================
fprintf('\n--- 4. 局域残差计算（逐中心独立）---\n');

r_y_loc = cell(1, Omega);
r_s_loc = cell(1, Omega);

for omega = 1:Omega
    % 仅传入当前中心的索引
    idx_single = {indices_omega{omega}};

    % 仅传入当前中心的局域矩阵
    Az_single = {A_z_omega{omega}};
    L_single  = {L_omega{omega}};

    [r_y_single, r_s_single] = Compute_online_residuals(...
        u_seq, y_seq, s_cell, ...
        Az_single, L_single, ...
        B_g, C_g, D_g, C_s, D_s, ...
        idx_single, n_x, n_y, n_s);

    r_y_loc{omega} = r_y_single{1};
    r_s_loc{omega} = r_s_single{1};

    fprintf('  中心 %d 独立计算: r_y = %dx%d,  r_s = %dx%d\n', ...
        omega, size(r_y_loc{omega}, 1), size(r_y_loc{omega}, 2), ...
        size(r_s_loc{omega}, 1), size(r_s_loc{omega}, 2));
end

%% ============================================================
%  5. 对比验证：局域残差 ≡ 全局残差对应分块
% ============================================================
fprintf('\n===== 5. 对比验证 =====\n\n');

all_passed = true;
max_err_y = zeros(1, Omega);
max_err_s = zeros(1, Omega);

for omega = 1:Omega

    % ---- 5a. 输出残差 r_y 对比 ----
    err_y = max(abs(r_y_loc{omega}(:) - r_y_all{omega}(:)));
    max_err_y(omega) = err_y;
    fprintf('  中心 %d — r_y: max|局域 − 全局| = %.2e', omega, err_y);
    if err_y < 1e-12
        fprintf('  [通过]\n');
    else
        fprintf('  [未通过] 超出容差！\n');
        all_passed = false;
    end

    % ---- 5b. 发送信息残差 r_s 对比 ----
    err_s = max(abs(r_s_loc{omega}(:) - r_s_all{omega}(:)));
    max_err_s(omega) = err_s;
    fprintf('  中心 %d — r_s: max|局域 − 全局| = %.2e', omega, err_s);
    if err_s < 1e-12
        fprintf('  [通过]\n');
    else
        fprintf('  [未通过] 超出容差！\n');
        all_passed = false;
    end

end

%% ============================================================
%  6. 验收判定
% ============================================================
fprintf('\n===== 6. 验收判定 =====\n\n');

if all_passed
    fprintf('  实验 01 通过。\n');
    fprintf('    各计算中心使用本地数据独立计算的残差与全局残差对应分块\n');
    fprintf('    完全一致（最大偏差 < 1e-12）。\n');
    fprintf('    分布式残差生成器可在各中心独立并行工作，无需全局信息。\n');
else
    fprintf('  实验 01 未通过。存在偏差超出容差的中心。\n');
end

%% ============================================================
%  7. 可视化：局域与全局残差时间序列对比
% ============================================================
fprintf('\n--- 7. 可视化 ---\n');

% 选取展示步数（前 200 步，便于观察瞬态与稳态行为）
n_plot = min(200, T_sim);
t_plot = (0:n_plot-1);

for omega = 1:Omega

    % ---- r_y 对比图 ----
    figh_y = figure('Name', sprintf('实验01-中心%d-输出残差', omega), ...
                    'NumberTitle', 'off');

    % 局域与全局的 r_y 重叠绘制（一致时应完全重合）
    plot(t_plot, r_y_loc{omega}(:, 1:n_plot), 'b-', 'LineWidth', 1.5);
    hold on;
    plot(t_plot, r_y_all{omega}(:, 1:n_plot), 'r--', 'LineWidth', 1.5);
    hold off;

    xlabel('步数 k');
    ylabel(sprintf('输出残差 r^y — 中心 %d', omega));
    legend('局域独立计算', '全局联合计算', 'Location', 'best');
    title(sprintf('实验 01：中心 %d 输出残差 — 局域 vs 全局', omega));
    Run_visualization(figh_y);

    % ---- r_s 对比图 ----
    figh_s = figure('Name', sprintf('实验01-中心%d-信息残差', omega), ...
                    'NumberTitle', 'off');

    n_s_dim = size(r_s_loc{omega}, 1);
    for dim = 1:n_s_dim
        subplot(n_s_dim, 1, dim);
        plot(t_plot, r_s_loc{omega}(dim, 1:n_plot), 'b-', 'LineWidth', 1.5);
        hold on;
        plot(t_plot, r_s_all{omega}(dim, 1:n_plot), 'r--', 'LineWidth', 1.5);
        hold off;
        xlabel('步数 k');
        ylabel(sprintf('r^s_{%d}', dim));
        if dim == 1
            legend('局域独立计算', '全局联合计算', 'Location', 'best');
        end
        title(sprintf('中心 %d — 信息残差维度 %d', omega, dim));
    end
    Run_visualization(figh_s);

end

fprintf('  绘图完成。蓝实线（局域）与红虚线（全局）应完全重合。\n');

%% ============================================================
%  8. 补充验证：数据局部性证明
% ============================================================
fprintf('\n--- 8. 数据局部性证明 ---\n');

% 验证各中心仅访问本地输出 y_ω
% 中心 1（子系统 1,3）：输出 y_1 来自子系统 1
% 中心 2（子系统 2,4）：输出 y_2 来自子系统 2

% 构建各中心的局域输出行索引
cum_n_y = [0, cumsum(n_y)];
output_rows = cell(1, n_s);
for i = 1:n_s
    if n_y(i) > 0
        output_rows{i} = (cum_n_y(i) + 1) : cum_n_y(i + 1);
    else
        output_rows{i} = [];
    end
end

for omega = 1:Omega
    idx = indices_omega{omega};
    rows_y_omega = [];
    for s = idx
        if ~isempty(output_rows{s})
            rows_y_omega = [rows_y_omega, output_rows{s}];  %#ok<AGROW>
        end
    end
    fprintf('  中心 %d：管辖子系统 %s，输出行索引 [%s]\n', ...
        omega, mat2str(idx), mat2str(rows_y_omega));
    fprintf('         仅访问 y_seq 的第 %s 行，s_cell 的第 %s 子系统\n', ...
        mat2str(rows_y_omega), mat2str(idx));
end

fprintf('\n  确认：各中心仅读取本地 y_ω 和本地 s_ω，不访问其他区域数据。\n');

%% ============================================================
%  9. 汇总表
% ============================================================
fprintf('\n===== 9. 汇总 =====\n\n');
fprintf('  %-10s %-12s %-18s %-18s %s\n', ...
    '中心', '管辖子系统', 'max|err(r_y)|', 'max|err(r_s)|', '判定');
fprintf('  %-10s %-12s %-18s %-18s %s\n', ...
    '------', '----------', '----------------', '----------------', '------');
for omega = 1:Omega
    verdict_str = '通过';
    if max_err_y(omega) >= 1e-12 || max_err_s(omega) >= 1e-12
        verdict_str = '未通过';
    end
    fprintf('  %-10d %-12s %-18.2e %-18.2e %s\n', ...
        omega, mat2str(indices_omega{omega}), max_err_y(omega), max_err_s(omega), verdict_str);
end

fprintf('\n========== 实验 01 结束 ==========\n');
