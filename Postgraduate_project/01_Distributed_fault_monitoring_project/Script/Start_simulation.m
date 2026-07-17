%% Start_simulation.m  四容水箱系统 LQR 闭环仿真数据生成
%  使用全局离散状态空间进行递推仿真，生成 x/u/y/s 时间序列，
%  供 Compute_online_residuals.m 和 Inject_fault.m 后处理使用。
%
%  动力学（全局离散，偏差变量）：
%      x_{k+1} = A_g * x_k + B_g * u_k + w_k
%      y_k     = C_g * x_k + D_g * u_k + v_k
%      u_k     = -K * x_k                          （LQR 反馈）
%      s_{i,k} = C_{s,i} * x_{i,k} + D_{s,i} * u_k （子系统信息信号）
%
%  输出（保存至 Simulation_data.mat）：
%      x_seq, u_seq, y_seq — 全局时间序列矩阵
%      s_cell              — 各子系统信息信号（cell array）
%      w_seq, v_seq        — 噪声序列
%      T_sim, k_fault      — 仿真参数

clear; clc;

% ====================================================
%  1. 路径添加与参数加载
% ====================================================
addpath(genpath('../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

% 直接加载 Model 1 与仿真参数（不调用 Init_parameters，因其内部 clear 会清空变量）
Create_model_1;

% ---- 计算中心划分 ----
Omega = 2;
indices_omega = {[1, 3], [2, 4]};

% ---- 仿真参数 ----
T_sim   = 1000;
k_fault = 500;

fprintf('===== Start_simulation =====\n');
fprintf('  T_sim = %d,  k_fault = %d\n', T_sim, k_fault);

% ====================================================
%  2. 获取被控系统与 LQR 控制器
% ====================================================
fprintf('\n--- 2. 加载被控系统与控制器 ---\n');

[A_g, B_g, C_g, D_g, x_eq, u_eq, y_eq] = Create_controlled_system();
K = Calculate_LQR(A_g, B_g);

fprintf('  A_g = %d×%d,  B_g = %d×%d,  C_g = %d×%d\n', ...
    size(A_g, 1), size(A_g, 2), size(B_g, 1), size(B_g, 2), ...
    size(C_g, 1), size(C_g, 2));
fprintf('  LQR 增益 K = %d×%d\n', size(K, 1), size(K, 2));

% ---- 全局维度 ----
N_x = size(A_g, 1);     % 全局状态维度 = 4
N_u = size(B_g, 2);     % 全局输入维度 = 2
N_y = size(C_g, 1);     % 全局输出维度 = 2

% ---- 状态索引映射（子系统 → 全局状态的偏移）----
cum_n_x = [0, cumsum(n_x)];
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% ---- 组装全局噪声协方差 ----
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});

fprintf('  Σ_w = %d×%d,  Σ_v = %d×%d\n', ...
    size(Sigma_w_full, 1), size(Sigma_w_full, 2), ...
    size(Sigma_v_full, 1), size(Sigma_v_full, 2));

% ====================================================
%  3. 生成噪声序列
% ====================================================
fprintf('\n--- 3. 生成噪声序列 ---\n');

rng(42);   % 固定随机种子，保证可复现

% 过程噪声 w_k（4 维）
[~, sim_w] = Create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);   % 4 × T_sim

% 测量噪声 v_k（2 维）
[~, sim_v] = Create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq = squeeze(sim_v.Data);   % 2 × T_sim

fprintf('  w_seq = %d×%d,  v_seq = %d×%d\n', ...
    size(w_seq, 1), size(w_seq, 2), size(v_seq, 1), size(v_seq, 2));

% ====================================================
%  4. 预分配存储
% ====================================================
fprintf('\n--- 4. 预分配存储 ---\n');

x_seq = zeros(N_x, T_sim);     % 状态轨迹 4 × T_sim
u_seq = zeros(N_u, T_sim);     % 输入轨迹 2 × T_sim
y_seq = zeros(N_y, T_sim);     % 输出轨迹 2 × T_sim

% 各子系统信息信号 s_{i,k}
s_cell = cell(1, n_s);
for i = 1:n_s
    s_cell{i} = zeros(n_x(i), T_sim);
end

% ====================================================
%  5. 仿真主循环
% ====================================================
fprintf('\n--- 5. 仿真进行中（%d 步）---\n', T_sim);

% 初始状态：偏差为零（系统处于平衡点）
x_seq(:, 1) = zeros(N_x, 1);

for k = 1:T_sim

    % ---- 5a. 当前状态 ----
    x_k = x_seq(:, k);

    % ---- 5b. LQR 控制律：u_k = -K * x_k ----
    u_k = -K * x_k;
    u_seq(:, k) = u_k;

    % ---- 5c. 状态递推（最后一步不递推）----
    if k < T_sim
        x_seq(:, k+1) = A_g * x_k + B_g * u_k + w_seq(:, k);
    end

    % ---- 5d. 输出计算 ----
    y_seq(:, k) = C_g * x_k + D_g * u_k + v_seq(:, k);

    % ---- 5e. 各子系统信息信号 s_{i,k} = C_{s,i}·x_{i,k} + D_{s,i}·u_k ----
    for i = 1:n_s
        idx = state_rows{i};
        s_cell{i}(:, k) = C_s{i} * x_k(idx) + D_s{i} * u_k;
    end

end

fprintf('  仿真完成。\n');

% ====================================================
%  6. 保存至 .mat 文件
% ====================================================
fprintf('\n--- 6. 保存数据 ---\n');

% 保存到当前工作目录（Script/）
save_file = 'Simulation_data.mat';
save(save_file, ...
    'x_seq', 'u_seq', 'y_seq', 's_cell', ...
    'w_seq', 'v_seq', ...
    'T_sim', 'k_fault', ...
    'n_s', 'n_x', 'n_y', 'n_u', ...
    'A_g', 'B_g', 'C_g', 'D_g', 'K', 'x_eq', 'u_eq', ...
    'Sigma_w', 'Sigma_v', ...
    'indices_omega', 'Omega');

fprintf('  数据已保存至: %s\n', fullfile(pwd, save_file));

% ====================================================
%  7. 汇总输出
% ====================================================
fprintf('\n===== 仿真汇总 =====\n');
fprintf('  仿真步数:       %d\n', T_sim);
fprintf('  故障注入时刻:   %d\n', k_fault);
fprintf('  状态 x_seq:     %d × %d\n', size(x_seq, 1), size(x_seq, 2));
fprintf('  输入 u_seq:     %d × %d\n', size(u_seq, 1), size(u_seq, 2));
fprintf('  输出 y_seq:     %d × %d\n', size(y_seq, 1), size(y_seq, 2));
fprintf('  信息 s_cell:    1×%d cell\n', n_s);
for i = 1:n_s
    fprintf('    s{%d}:         %d × %d\n', i, size(s_cell{i}, 1), size(s_cell{i}, 2));
end
fprintf('  噪声 w_seq:     %d × %d\n', size(w_seq, 1), size(w_seq, 2));
fprintf('  噪声 v_seq:     %d × %d\n', size(v_seq, 1), size(v_seq, 2));
fprintf('  计算中心:       %d 个\n', Omega);

% ---- 快速验证：LQR 闭环稳定性 ----
eig_cl = abs(eig(A_g - B_g * K));
fprintf('  闭环 max|λ|:    %.6f', max(eig_cl));
if all(eig_cl < 1)
    fprintf('  ✓（稳定）\n');
else
    fprintf('  ✗（不稳定！）\n');
end

% ---- 快速验证：状态收敛性 ----
fprintf('  初始状态范数:   %.4f\n', norm(x_seq(:, 1)));
fprintf('  终态范数:       %.4f\n', norm(x_seq(:, end)));

fprintf('\nStart_simulation 完成。\n');
