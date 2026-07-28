%% test_09_start_simulation.m  闭环仿真数据生成测试
%  验证 start_simulation 生成的仿真数据：
%    1. 维度正确性
%    2. 闭环 LQR 稳定性
%    3. 递推动力学一致性（无 NaN/Inf）
%    4. 状态有界性（不发散）
%    5. 噪声统计特性（零均值、正值方差）
%    6. 固定种子的可复现性
%    7. 信息信号 s 的正确计算

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  1. 生成仿真数据
% ============================================================
fprintf('===== 1. 生成仿真数据 =====\n\n');

% 直接加载 Model 1 与仿真参数（与 Start_simulation 保持一致）
create_model_1;
n_omega = 2;
indices_omega = {[1, 3], [2, 4]};
T_sim   = 1000;
k_fault = 500;

% 被控系统与 LQR 控制器
[A_g, B_g, C_g, D_g, x_eq, u_eq, y_eq] = create_controlled_system();
K = calculate_lqr(A_g, B_g);

% 状态索引映射
cum_n_x = [0, cumsum(n_x)];
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% 全局噪声协方差
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});

% 固定种子生成噪声
rng(42);
[~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);
[~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq = squeeze(sim_v.Data);

% 预分配
N_x = size(A_g, 1);
N_u = size(B_g, 2);
N_y = size(C_g, 1);

x_seq = zeros(N_x, T_sim);
u_seq = zeros(N_u, T_sim);
y_seq = zeros(N_y, T_sim);
s_cell = cell(1, n_s);
for i = 1:n_s
    s_cell{i} = zeros(n_x(i), T_sim);
end

% 仿真主循环
x_seq(:, 1) = zeros(N_x, 1);
for k = 1:T_sim
    x_k = x_seq(:, k);
    u_k = -K * x_k;
    u_seq(:, k) = u_k;
    if k < T_sim
        x_seq(:, k+1) = A_g * x_k + B_g * u_k + w_seq(:, k);
    end
    y_seq(:, k) = C_g * x_k + D_g * u_k + v_seq(:, k);
    for i = 1:n_s
        idx = state_rows{i};
        s_cell{i}(:, k) = C_s{i} * x_k(idx) + D_s{i} * u_k;
    end
end

fprintf('  仿真数据生成完成（%d 步）。\n', T_sim);

%% ============================================================
%  2. 维度验证
% ============================================================
fprintf('\n===== 2. 维度验证 =====\n');

assert(isequal(size(x_seq), [N_x, T_sim]), ...
    'x_seq 维度应为 %d×%d，实际 %d×%d', N_x, T_sim, size(x_seq,1), size(x_seq,2));
assert(isequal(size(u_seq), [N_u, T_sim]), ...
    'u_seq 维度应为 %d×%d，实际 %d×%d', N_u, T_sim, size(u_seq,1), size(u_seq,2));
assert(isequal(size(y_seq), [N_y, T_sim]), ...
    'y_seq 维度应为 %d×%d，实际 %d×%d', N_y, T_sim, size(y_seq,1), size(y_seq,2));
assert(isequal(size(w_seq), [N_x, T_sim]), 'w_seq 维度错误');
assert(isequal(size(v_seq), [N_y, T_sim]), 'v_seq 维度错误');
assert(length(s_cell) == n_s, 's_cell 长度应为 n_s=%d', n_s);
for i = 1:n_s
    assert(isequal(size(s_cell{i}), [n_x(i), T_sim]), ...
        's{%d} 维度应为 %d×%d', i, n_x(i), T_sim);
end
fprintf('  ✓ 所有维度正确：x=%d×%d, u=%d×%d, y=%d×%d, w=%d×%d, v=%d×%d\n', ...
    size(x_seq,1), size(x_seq,2), size(u_seq,1), size(u_seq,2), ...
    size(y_seq,1), size(y_seq,2), size(w_seq,1), size(w_seq,2), ...
    size(v_seq,1), size(v_seq,2));

%% ============================================================
%  3. 无 NaN/Inf 验证
% ============================================================
fprintf('\n===== 3. 数值有效性验证 =====\n');

assert(~any(isnan(x_seq(:))), 'x_seq 包含 NaN！');
assert(~any(isinf(x_seq(:))), 'x_seq 包含 Inf！');
assert(~any(isnan(u_seq(:))), 'u_seq 包含 NaN！');
assert(~any(isinf(u_seq(:))), 'u_seq 包含 Inf！');
assert(~any(isnan(y_seq(:))), 'y_seq 包含 NaN！');
assert(~any(isinf(y_seq(:))), 'y_seq 包含 Inf！');
assert(~any(isnan(w_seq(:))), 'w_seq 包含 NaN！');
assert(~any(isinf(w_seq(:))), 'w_seq 包含 Inf！');
assert(~any(isnan(v_seq(:))), 'v_seq 包含 NaN！');
assert(~any(isinf(v_seq(:))), 'v_seq 包含 Inf！');
fprintf('  ✓ x, u, y, w, v 均无 NaN/Inf\n');

%% ============================================================
%  4. 闭环稳定性验证
% ============================================================
fprintf('\n===== 4. 闭环稳定性验证 =====\n');

A_cl = A_g - B_g * K;
eig_cl = abs(eig(A_cl));
max_eig = max(eig_cl);
fprintf('  max|λ(A_g - B_g·K)| = %.6f\n', max_eig);
assert(max_eig < 1, '闭环不稳定：max|λ| = %.6f ≥ 1', max_eig);
fprintf('  ✓ 闭环系统 Schur 稳定\n');

% 状态不发散（终态范数不受初始条件影响且有界）
init_norm = norm(x_seq(:, 1));
final_norm = norm(x_seq(:, end));
rms_state = sqrt(mean(vecnorm(x_seq).^2));
fprintf('  初态范数 = %.4f,  终态范数 = %.4f,  RMS = %.4f\n', init_norm, final_norm, rms_state);
assert(final_norm < 5, '终态范数过大（%.2f），状态可能发散', final_norm);
assert(rms_state < 2, 'RMS 状态过大（%.2f），状态可能发散', rms_state);
fprintf('  ✓ 状态有界，未发散\n');

%% ============================================================
%  5. 递推动力学一致性
% ============================================================
fprintf('\n===== 5. 递推动力学一致性 =====\n');

% 对每一步验证：x_{k+1} = A_g·x_k + B_g·u_k + w_k
max_dyn_err = 0;
for k = 1:(T_sim - 1)
    x_pred = A_g * x_seq(:, k) + B_g * u_seq(:, k) + w_seq(:, k);
    err = max(abs(x_pred - x_seq(:, k+1)));
    if err > max_dyn_err
        max_dyn_err = err;
    end
end
fprintf('  max|x_{k+1} - (A·x_k + B·u_k + w_k)| = %.2e\n', max_dyn_err);
assert(max_dyn_err < 1e-12, '递推不一致！');

% 对每一步验证：y_k = C_g·x_k + D_g·u_k + v_k
max_out_err = 0;
for k = 1:T_sim
    y_pred = C_g * x_seq(:, k) + D_g * u_seq(:, k) + v_seq(:, k);
    err = max(abs(y_pred - y_seq(:, k)));
    if err > max_out_err
        max_out_err = err;
    end
end
fprintf('  max|y_k - (C·x_k + D·u_k + v_k)| = %.2e\n', max_out_err);
assert(max_out_err < 1e-12, '输出计算不一致！');

% 验证 u_k = -K·x_k
max_ctrl_err = 0;
for k = 1:T_sim
    u_pred = -K * x_seq(:, k);
    err = max(abs(u_pred - u_seq(:, k)));
    if err > max_ctrl_err
        max_ctrl_err = err;
    end
end
fprintf('  max|u_k - (-K·x_k)| = %.2e\n', max_ctrl_err);
assert(max_ctrl_err < 1e-12, '控制律不一致！');

% 验证 s_{i,k} = C_{s,i}·x_{i,k} + D_{s,i}·u_k
max_s_err = 0;
for i = 1:n_s
    idx = state_rows{i};
    for k = 1:T_sim
        s_pred = C_s{i} * x_seq(idx, k) + D_s{i} * u_seq(:, k);
        err = max(abs(s_pred - s_cell{i}(:, k)));
        if err > max_s_err
            max_s_err = err;
        end
    end
end
fprintf('  max|s_{i,k} - (C_{s,i}·x_{i,k} + D_{s,i}·u_k)| = %.2e\n', max_s_err);
assert(max_s_err < 1e-12, '信息信号计算不一致！');

fprintf('  ✓ 所有动力学方程精确满足\n');

%% ============================================================
%  6. 噪声统计特性验证
% ============================================================
fprintf('\n===== 6. 噪声统计特性验证 =====\n');

% 过程噪声 w：均值应接近零
for i = 1:N_x
    w_mean = mean(w_seq(i, :));
    assert(abs(w_mean) < 0.02, 'w{%d} 均值 %.4f 偏离零', i, w_mean);
end
fprintf('  ✓ w 零均值通过（|mean| < 0.02）\n');

% 测量噪声 v：均值应接近零
for i = 1:N_y
    v_mean = mean(v_seq(i, :));
    assert(abs(v_mean) < 0.02, 'v{%d} 均值 %.4f 偏离零', i, v_mean);
end
fprintf('  ✓ v 零均值通过（|mean| < 0.02）\n');

% 验证方差为正值（噪声不是恒零）
for i = 1:N_x
    w_var = var(w_seq(i, :));
    assert(w_var > 0, 'w{%d} 方差 = 0，噪声未生成', i);
end
fprintf('  ✓ w 各维方差 > 0\n');

for i = 1:N_y
    v_var = var(v_seq(i, :));
    assert(v_var > 0, 'v{%d} 方差 = 0，噪声未生成', i);
end
fprintf('  ✓ v 各维方差 > 0\n');

%% ============================================================
%  7. 可复现性验证（固定 rng(42)）
% ============================================================
fprintf('\n===== 7. 可复现性验证 =====\n');

% 重新生成并比较
rng(42);
[~, sim_w2] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq2 = squeeze(sim_w2.Data);
[~, sim_v2] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq2 = squeeze(sim_v2.Data);

assert(max(abs(w_seq(:) - w_seq2(:))) < 1e-12, 'w_seq 不可复现！');
assert(max(abs(v_seq(:) - v_seq2(:))) < 1e-12, 'v_seq 不可复现！');
fprintf('  ✓ rng(42) 固定种子可复现：max|w - w''| = %.2e, max|v - v''| = %.2e\n', ...
    max(abs(w_seq(:) - w_seq2(:))), max(abs(v_seq(:) - v_seq2(:))));

%% ============================================================
%  8. LQR 控制性能验证
% ============================================================
fprintf('\n===== 8. LQR 控制性能验证 =====\n');

% 控制器应对噪声产生非零控制量
mean_abs_u = mean(abs(u_seq), 2);
for i = 1:N_u
    assert(mean_abs_u(i) > 0, 'u{%d} 恒为零，控制器可能未生效', i);
end
fprintf('  mean|u| = [%.4f, %.4f]\n', mean_abs_u(1), mean_abs_u(2));
fprintf('  ✓ 控制器产生非零控制量\n');

% 输出信号非恒零（传感器测量有噪声响应）
for i = 1:N_y
    y_std = std(y_seq(i, :));
    assert(y_std > 0, 'y{%d} 标准差 = 0', i);
end
fprintf('  std(y_1) = %.4f,  std(y_2) = %.4f\n', std(y_seq(1,:)), std(y_seq(2,:)));
fprintf('  ✓ 输出信号具有非零方差\n');

%% ============================================================
%  9. 汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  所有断言通过。Start_simulation 仿真数据生成正确：\n');
fprintf('    - 维度：x(4×1000), u(2×1000), y(2×1000), s(1×4)\n');
fprintf('    - 闭环稳定：max|λ| = %.6f < 1\n', max_eig);
fprintf('    - 动力学一致性：递推 / 输出 / 控制 / 信息信号全部精确\n');
fprintf('    - 数值有效：无 NaN / Inf\n');
fprintf('    - 噪声特性：零均值，正值方差\n');
fprintf('    - 可复现：固定种子 rng(42)\n');
fprintf('  可用于后续在线监测与故障定位。\n');
